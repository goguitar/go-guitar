use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AudioError {
    #[error("Channel not found: {0}")]
    ChannelNotFound(i32),
    #[error("Audio not loaded: {0}")]
    AudioNotLoaded(i32),
    #[error("Playback error: {0}")]
    PlaybackError(String),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum AudioChannel {
    LeadGuitar = 0,
    RhythmGuitar = 1,
    Bass = 2,
    Music = 3,
    PlayerInput = 4,
}

impl AudioChannel {
    pub fn from_int(v: i32) -> Option<Self> {
        match v {
            0 => Some(Self::LeadGuitar),
            1 => Some(Self::RhythmGuitar),
            2 => Some(Self::Bass),
            3 => Some(Self::Music),
            4 => Some(Self::PlayerInput),
            _ => None,
        }
    }
}

#[derive(Clone)]
pub struct AudioTrack {
    pub samples: Vec<f32>,
    pub sample_rate: u32,
    pub channels: u16,
    pub position: usize,
    pub volume: f32,
    pub playing: bool,
}

impl AudioTrack {
    pub fn new(samples: Vec<f32>, sample_rate: u32, channels: u16) -> Self {
        Self {
            samples,
            sample_rate,
            channels,
            position: 0,
            volume: 1.0,
            playing: false,
        }
    }

    pub fn get_samples(&mut self, num_samples: usize) -> Vec<f32> {
        if !self.playing || self.position >= self.samples.len() {
            return vec![0.0; num_samples];
        }

        let end = std::cmp::min(self.position + num_samples, self.samples.len());
        let mut result = self.samples[self.position..end].to_vec();

        if result.len() < num_samples {
            result.resize(num_samples, 0.0);
        }

        self.position = end;
        result
    }

    pub fn reset(&mut self) {
        self.position = 0;
    }

    pub fn is_finished(&self) -> bool {
        self.position >= self.samples.len()
    }
}

pub struct AudioMixer {
    tracks: Arc<RwLock<HashMap<i32, AudioTrack>>>,
    channel_volumes: HashMap<AudioChannel, f32>,
    master_volume: f32,
    current_time_ms: u64,
    sample_rate: u32,
}

impl AudioMixer {
    pub fn new(sample_rate: u32) -> Self {
        let mut channel_volumes = HashMap::new();
        channel_volumes.insert(AudioChannel::LeadGuitar, 0.8);
        channel_volumes.insert(AudioChannel::RhythmGuitar, 0.7);
        channel_volumes.insert(AudioChannel::Bass, 0.9);
        channel_volumes.insert(AudioChannel::Music, 1.0);
        channel_volumes.insert(AudioChannel::PlayerInput, 1.0);

        Self {
            tracks: Arc::new(RwLock::new(HashMap::new())),
            channel_volumes,
            master_volume: 1.0,
            current_time_ms: 0,
            sample_rate,
        }
    }

    pub fn load_audio(&self, audio_id: i32, samples: Vec<f32>, sample_rate: u32, channels: u16) {
        let track = AudioTrack::new(samples, sample_rate, channels);
        if let Ok(mut tracks) = self.tracks.write() {
            tracks.insert(audio_id, track);
        }
    }

    pub fn play_channel(&self, audio_id: i32, channel: AudioChannel) -> Result<(), AudioError> {
        if let Ok(mut tracks) = self.tracks.write() {
            if let Some(track) = tracks.get_mut(&audio_id) {
                track.playing = true;
                Ok(())
            } else {
                Err(AudioError::AudioNotLoaded(audio_id))
            }
        } else {
            Err(AudioError::PlaybackError(
                "Failed to lock tracks".to_string(),
            ))
        }
    }

    pub fn stop_channel(&self, audio_id: i32) -> Result<(), AudioError> {
        if let Ok(mut tracks) = self.tracks.write() {
            if let Some(track) = tracks.get_mut(&audio_id) {
                track.playing = false;
                Ok(())
            } else {
                Err(AudioError::AudioNotLoaded(audio_id))
            }
        } else {
            Err(AudioError::PlaybackError(
                "Failed to lock tracks".to_string(),
            ))
        }
    }

    pub fn set_channel_volume(&mut self, channel: AudioChannel, volume: f32) {
        self.channel_volumes.insert(channel, volume.clamp(0.0, 1.0));
    }

    pub fn set_master_volume(&mut self, volume: f32) {
        self.master_volume = volume.clamp(0.0, 1.0);
    }

    pub fn get_samples(&self, num_samples: usize) -> Vec<f32> {
        let mut output = vec![0.0_f32; num_samples];

        if let Ok(tracks) = self.tracks.read() {
            for track in tracks.values() {
                if !track.playing {
                    continue;
                }

                let channel_volume = *self
                    .channel_volumes
                    .get(&AudioChannel::Music)
                    .unwrap_or(&1.0);

                let samples = {
                    let mut t = track.clone();
                    t.playing = track.playing;
                    t.get_samples(num_samples)
                };

                for (i, &sample) in samples.iter().enumerate() {
                    output[i] += sample * channel_volume * self.master_volume;
                }
            }
        }

        // Normalize output
        let max_sample = output.iter().map(|s| s.abs()).fold(0.0_f32, f32::max);
        if max_sample > 1.0 {
            for sample in &mut output {
                *sample /= max_sample;
            }
        }

        output
    }

    pub fn seek(&mut self, time_ms: u64) {
        self.current_time_ms = time_ms;

        if let Ok(mut tracks) = self.tracks.write() {
            for track in tracks.values_mut() {
                let sample_pos = ((time_ms as f64 / 1000.0) * track.sample_rate as f64) as usize;
                track.position = sample_pos.min(track.samples.len());
            }
        }
    }

    pub fn update_time(&mut self, delta_ms: u64) {
        self.current_time_ms += delta_ms;
    }

    pub fn reset(&mut self) {
        if let Ok(mut tracks) = self.tracks.write() {
            for track in tracks.values_mut() {
                track.position = 0;
                track.playing = false;
            }
        }
        self.current_time_ms = 0;
    }

    pub fn get_sample_rate(&self) -> u32 {
        self.sample_rate
    }

    pub fn get_current_time_ms(&self) -> u64 {
        self.current_time_ms
    }
}

impl Default for AudioMixer {
    fn default() -> Self {
        Self::new(48000)
    }
}

#[cfg(feature = "audio")]
pub mod audio_output {
    use super::*;

    pub fn list_audio_devices() -> Vec<String> {
        use cpal::devices;

        let mut devices = Vec::new();
        if let Ok(enumerator) = devices(cpal::ALL_DEVICES) {
            for (idx, device) in enumerator.enumerate() {
                if let Ok(name) = device.name() {
                    devices.push(format!("{}: {}", idx, name));
                }
            }
        }
        devices
    }

    pub struct DiInput {
        device_index: usize,
        sample_rate: u32,
    }

    impl DiInput {
        pub fn new(device_index: usize, sample_rate: u32) -> Option<Self> {
            Some(Self {
                device_index,
                sample_rate,
            })
        }
    }
}
