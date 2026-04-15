use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::path::Path;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PsarcError {
    #[error("Failed to open PSARC file: {0}")]
    OpenError(String),
    #[error("Failed to read PSARC: {0}")]
    ReadError(String),
    #[error("Failed to extract file: {0}")]
    ExtractionError(String),
    #[error("File not found in archive: {0}")]
    FileNotFound(String),
}

#[derive(Clone, Debug)]
pub struct ArrangementInfo {
    pub name: String,
    pub filename: String,
    pub arrangement_type: ArrangementType,
}

#[derive(Clone, Debug, PartialEq)]
pub enum ArrangementType {
    Lead,
    Rhythm,
    Bass,
    Vocal,
    Showlight,
}

impl ArrangementType {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "lead" => ArrangementType::Lead,
            "rhythm" => ArrangementType::Rhythm,
            "bass" => ArrangementType::Bass,
            "vocal" => ArrangementType::Vocal,
            "showlight" => ArrangementType::Showlight,
            _ => ArrangementType::Lead,
        }
    }
}

#[derive(Clone)]
pub struct DlcSong {
    pub title: String,
    pub artist: String,
    pub album: Option<String>,
    pub year: Option<i32>,
    pub arrangements: Vec<ArrangementInfo>,
    pub audio_files: Vec<String>,
}

pub struct PsarcArchive {
    entries: HashMap<String, Vec<u8>>,
}

impl PsarcArchive {
    pub fn open(path: &Path) -> Result<Self, PsarcError> {
        let file = File::open(path).map_err(|e| PsarcError::OpenError(e.to_string()))?;

        let mut reader = BufReader::new(file);
        let mut psarc = rocksmith2014_psarc::Psarc::read(&mut reader)
            .map_err(|e| PsarcError::ReadError(e.to_string()))?;

        let mut entries = HashMap::new();
        let manifest = psarc.manifest().to_vec();

        for filename in manifest {
            match psarc.inflate_file(&filename) {
                Ok(data) => {
                    entries.insert(filename, data);
                }
                Err(e) => {
                    log::warn!("Failed to inflate file '{}': {}", filename, e);
                }
            }
        }

        Ok(Self { entries })
    }

    pub fn from_bytes(data: &[u8]) -> Result<Self, PsarcError> {
        let mut cursor = std::io::Cursor::new(data);
        let mut psarc = rocksmith2014_psarc::Psarc::read(&mut cursor)
            .map_err(|e| PsarcError::ReadError(e.to_string()))?;

        let mut entries = HashMap::new();
        let manifest = psarc.manifest().to_vec();

        for filename in manifest {
            match psarc.inflate_file(&filename) {
                Ok(file_data) => {
                    entries.insert(filename, file_data);
                }
                Err(e) => {
                    log::warn!("Failed to inflate file '{}': {}", filename, e);
                }
            }
        }

        Ok(Self { entries })
    }

    pub fn extract(&self, filename: &str) -> Result<&[u8], PsarcError> {
        self.entries
            .get(filename)
            .map(|v| v.as_slice())
            .ok_or_else(|| PsarcError::FileNotFound(filename.to_string()))
    }

    pub fn has_file(&self, filename: &str) -> bool {
        self.entries.contains_key(filename)
    }

    pub fn list_files(&self) -> Vec<String> {
        self.entries.keys().cloned().collect()
    }

    pub fn get_audio_files(&self) -> Vec<String> {
        self.entries
            .keys()
            .filter(|f| f.ends_with(".wem") || f.ends_with(".ogg"))
            .cloned()
            .collect()
    }

    pub fn get_xml_files(&self) -> Vec<String> {
        self.entries
            .keys()
            .filter(|f| f.ends_with(".xml"))
            .cloned()
            .collect()
    }
}

pub struct DlcLoader {
    loaded_archives: HashMap<String, PsarcArchive>,
    loaded_songs: HashMap<String, DlcSong>,
}

impl DlcLoader {
    pub fn new() -> Self {
        Self {
            loaded_archives: HashMap::new(),
            loaded_songs: HashMap::new(),
        }
    }

    pub fn load_dlc(&mut self, path: &Path) -> Result<DlcSong, PsarcError> {
        let path_str = path.to_string_lossy().to_string();

        if let Some(song) = self.loaded_songs.get(&path_str) {
            return Ok(song.clone());
        }

        let archive = PsarcArchive::open(path)?;
        let song = self.parse_song(&archive, &path_str)?;

        self.loaded_archives.insert(path_str.clone(), archive);
        self.loaded_songs.insert(path_str, song.clone());

        Ok(song)
    }

    pub fn load_dlc_from_bytes(&mut self, data: &[u8], key: &str) -> Result<DlcSong, PsarcError> {
        if let Some(song) = self.loaded_songs.get(key) {
            return Ok(song.clone());
        }

        let archive = PsarcArchive::from_bytes(data)?;
        let song = self.parse_song(&archive, key)?;

        self.loaded_archives.insert(key.to_string(), archive);
        self.loaded_songs.insert(key.to_string(), song.clone());

        Ok(song)
    }

    fn parse_song(&self, archive: &PsarcArchive, key: &str) -> Result<DlcSong, PsarcError> {
        let xml_files = archive.get_xml_files();

        let mut arrangements = Vec::new();
        let audio_files = archive.get_audio_files();

        for xml_file in &xml_files {
            if let Ok(xml_content) = archive.extract(xml_file) {
                if let Some(info) = self.parse_arrangement_xml(xml_content, xml_file) {
                    arrangements.push(info);
                }
            }
        }

        let (title, artist) = self.extract_metadata_from_key(key);

        Ok(DlcSong {
            title,
            artist,
            album: None,
            year: None,
            arrangements,
            audio_files,
        })
    }

    fn parse_arrangement_xml(&self, data: &[u8], filename: &str) -> Option<ArrangementInfo> {
        let content = String::from_utf8_lossy(data);

        let arrangement_type = if content.contains("ArrangementType=\"Lead\"") {
            ArrangementType::Lead
        } else if content.contains("ArrangementType=\"Rhythm\"") {
            ArrangementType::Rhythm
        } else if content.contains("ArrangementType=\"Bass\"") {
            ArrangementType::Bass
        } else {
            return None;
        };

        let name = self
            .extract_xml_value(&content, "Name")
            .unwrap_or_else(|| filename.replace(".xml", ""));

        Some(ArrangementInfo {
            name,
            filename: filename.to_string(),
            arrangement_type,
        })
    }

    fn extract_xml_value(&self, content: &str, tag: &str) -> Option<String> {
        let start_tag = format!("<{}", tag);
        let end_tag = format!("</{}>", tag);

        if let Some(start_pos) = content.find(&start_tag) {
            if let Some(value_start) = content[start_pos..].find('>') {
                let value_start = start_pos + value_start + 1;
                if let Some(end_pos) = content[value_start..].find(&end_tag) {
                    return Some(content[value_start..value_start + end_pos].to_string());
                }
            }
        }
        None
    }

    fn extract_metadata_from_key(&self, key: &str) -> (String, String) {
        let filename = Path::new(key)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("Unknown");

        let parts: Vec<&str> = filename.split('_').collect();

        if parts.len() >= 2 {
            let artist = parts[0].replace('-', " ").replace('_', " ");
            let title = parts[1..].join(" ").replace('-', " ").replace('_', " ");
            (title, artist)
        } else {
            (filename.to_string(), "Unknown Artist".to_string())
        }
    }

    pub fn extract_audio(
        &self,
        song_key: &str,
        audio_filename: &str,
    ) -> Result<Vec<u8>, PsarcError> {
        let archive = self
            .loaded_archives
            .get(song_key)
            .ok_or_else(|| PsarcError::OpenError("Song not loaded".to_string()))?;

        archive.extract(audio_filename).map(|v| v.to_vec())
    }

    pub fn extract_arrangement(
        &self,
        song_key: &str,
        arrangement_filename: &str,
    ) -> Result<String, PsarcError> {
        let archive = self
            .loaded_archives
            .get(song_key)
            .ok_or_else(|| PsarcError::OpenError("Song not loaded".to_string()))?;

        let data = archive.extract(arrangement_filename)?;
        String::from_utf8(data.to_vec()).map_err(|e| PsarcError::ExtractionError(e.to_string()))
    }

    pub fn list_loaded_songs(&self) -> Vec<DlcSong> {
        self.loaded_songs.values().cloned().collect()
    }

    pub fn get_song(&self, key: &str) -> Option<DlcSong> {
        self.loaded_songs.get(key).cloned()
    }
}

impl Default for DlcLoader {
    fn default() -> Self {
        Self::new()
    }
}
