use std::collections::HashMap;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ArrangementError {
    #[error("Failed to parse XML: {0}")]
    XmlParseError(String),
    #[error("Failed to parse SNG: {0}")]
    SngParseError(String),
    #[error("Invalid arrangement data: {0}")]
    InvalidData(String),
}

#[derive(Clone, Debug)]
pub struct Note {
    pub fret: i32,
    pub string: i32,
    pub time: f64,
    pub duration: Option<f64>,
    pub hopo: bool,
    pub palm_mute: bool,
    pub harmonic: bool,
    pub bend: Option<f64>,
    pub slide: Option<i32>,
    pub vibrato: bool,
}

#[derive(Clone, Debug)]
pub struct Chord {
    pub notes: Vec<Note>,
    pub time: f64,
    pub duration: Option<f64>,
    pub name: Option<String>,
}

#[derive(Clone, Debug)]
pub struct Phrase {
    pub name: String,
    pub start_time: f64,
    pub end_time: f64,
    pub difficulty: i32,
}

#[derive(Clone, Debug)]
pub struct Section {
    pub name: String,
    pub start_time: f64,
    pub end_time: f64,
    pub number: i32,
}

#[derive(Clone, Debug)]
pub struct Arrangement {
    pub name: String,
    pub arrangement_type: ArrangementType,
    pub start_time: f64,
    pub notes: Vec<Note>,
    pub chords: Vec<Chord>,
    pub phrases: Vec<Phrase>,
    pub sections: Vec<Section>,
    pub difficulty: i32,
    pub song_length: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub enum ArrangementType {
    Lead,
    Rhythm,
    Bass,
    Vocal,
    Showlight,
}

impl Arrangement {
    pub fn from_xml(xml_content: &str) -> Result<Self, ArrangementError> {
        let mut arrangement = Arrangement {
            name: String::new(),
            arrangement_type: ArrangementType::Lead,
            start_time: 0.0,
            notes: Vec::new(),
            chords: Vec::new(),
            phrases: Vec::new(),
            sections: Vec::new(),
            difficulty: 0,
            song_length: 0.0,
        };

        arrangement.name = extract_xml_value(xml_content, "Name").unwrap_or_default();

        arrangement.arrangement_type = extract_xml_value(xml_content, "ArrangementType")
            .map(|s| match s.as_str() {
                "Lead" => ArrangementType::Lead,
                "Rhythm" => ArrangementType::Rhythm,
                "Bass" => ArrangementType::Bass,
                "Vocal" => ArrangementType::Vocal,
                "Showlight" => ArrangementType::Showlight,
                _ => ArrangementType::Lead,
            })
            .unwrap_or(ArrangementType::Lead);

        arrangement.difficulty = extract_xml_value(xml_content, "Difficulty")
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);

        arrangement.start_time = extract_xml_value(xml_content, "StartTime")
            .and_then(|s| s.parse().ok())
            .unwrap_or(0.0);

        arrangement.song_length = extract_xml_value(xml_content, "SongLength")
            .and_then(|s| s.parse().ok())
            .unwrap_or(0.0);

        Ok(arrangement)
    }
}

fn extract_xml_value<'a>(content: &'a str, tag: &str) -> Option<String> {
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

pub struct NoteChart {
    pub arrangements: Vec<Arrangement>,
    pub tempo_events: Vec<(f64, f64)>,
}

impl NoteChart {
    pub fn new() -> Self {
        Self {
            arrangements: Vec::new(),
            tempo_events: Vec::new(),
        }
    }

    pub fn from_xml_arrangements(
        xml_contents: &[(String, String)],
    ) -> Result<Self, ArrangementError> {
        let mut chart = Self::new();

        for (name, xml) in xml_contents {
            match Arrangement::from_xml(xml) {
                Ok(mut arrangement) => {
                    if arrangement.name.is_empty() {
                        arrangement.name = name.clone();
                    }
                    chart.arrangements.push(arrangement);
                }
                Err(e) => {
                    log::warn!("Failed to parse arrangement '{}': {}", name, e);
                }
            }
        }

        Ok(chart)
    }

    pub fn get_arrangement(&self, arr_type: &ArrangementType) -> Option<&Arrangement> {
        self.arrangements
            .iter()
            .find(|a| &a.arrangement_type == arr_type)
    }

    pub fn get_notes_at_time(
        &self,
        time: f64,
        window: f64,
        arr_type: &ArrangementType,
    ) -> Vec<&Note> {
        if let Some(arr) = self.get_arrangement(arr_type) {
            arr.notes
                .iter()
                .filter(|n| (n.time - time).abs() <= window)
                .collect()
        } else {
            Vec::new()
        }
    }

    pub fn get_chord_at_time(
        &self,
        time: f64,
        window: f64,
        arr_type: &ArrangementType,
    ) -> Option<&Chord> {
        if let Some(arr) = self.get_arrangement(arr_type) {
            arr.chords.iter().find(|c| (c.time - time).abs() <= window)
        } else {
            None
        }
    }
}

impl Default for NoteChart {
    fn default() -> Self {
        Self::new()
    }
}
