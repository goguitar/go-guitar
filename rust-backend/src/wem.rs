use std::sync::Arc;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum WemError {
    #[error("Failed to initialize vgmstream: {0}")]
    InitError(String),
    #[error("Failed to decode audio: {0}")]
    DecodeError(String),
    #[error("Invalid audio data: {0}")]
    InvalidData(String),
}

pub struct WemDecoder {
    sample_rate: u32,
    channels: u16,
    total_samples: i32,
    _phantom: std::marker::PhantomData<()>,
}

impl WemDecoder {
    pub fn new() -> Self {
        Self {
            sample_rate: 48000,
            channels: 2,
            total_samples: 0,
            _phantom: std::marker::PhantomData,
        }
    }

    pub fn get_sample_rate(&self) -> u32 {
        self.sample_rate
    }

    pub fn get_channels(&self) -> u16 {
        self.channels
    }

    pub fn get_total_samples(&self) -> i32 {
        self.total_samples
    }

    #[cfg(feature = "vgmstream")]
    pub fn decode_file(&mut self, path: &str) -> Result<Vec<i16>, WemError> {
        use std::ffi::CString;

        let c_path = CString::new(path).map_err(|e| WemError::InvalidData(e.to_string()))?;

        let vgmstream = unsafe { vgmstream_sys::init_vgmstream_from_stdio(c_path.as_ptr()) };

        if vgmstream.is_null() {
            return Err(WemError::InitError(
                "Failed to initialize vgmstream".to_string(),
            ));
        }

        let num_samples = 48000 * 60; // Assume max 1 minute for now
        let mut buffer = vec![0i16; num_samples];

        let samples_decoded = unsafe {
            vgmstream_sys::render_vgmstream2(buffer.as_mut_ptr(), num_samples as i32, vgmstream)
        };

        unsafe {
            vgmstream_sys::close_vgmstream(vgmstream);
        }

        if samples_decoded < 0 {
            return Err(WemError::DecodeError("Rendering failed".to_string()));
        }

        self.total_samples = samples_decoded;
        buffer.truncate(samples_decoded as usize);
        Ok(buffer)
    }

    #[cfg(not(feature = "vgmstream"))]
    pub fn decode_file(&mut self, _path: &str) -> Result<Vec<i16>, WemError> {
        Err(WemError::InvalidData(
            "vgmstream feature not enabled".to_string(),
        ))
    }
}

impl Default for WemDecoder {
    fn default() -> Self {
        Self::new()
    }
}

pub fn decode_wem_to_pcm(_wem_data: &[u8], _sample_rate: u32) -> Result<Vec<i16>, WemError> {
    #[cfg(feature = "vgmstream")]
    {
        Err(WemError::InvalidData(
            "vgmstream requires file-based input. Use WemDecoder::decode_file() instead."
                .to_string(),
        ))
    }

    #[cfg(not(feature = "vgmstream"))]
    {
        Err(WemError::InvalidData(
            "vgmstream feature not enabled - enable vgmstream feature and build vgmstream library first".to_string()
        ))
    }
}

pub fn decode_wem_to_wav(_wem_path: &str, _output_path: &str) -> Result<(u32, u16, i32), WemError> {
    #[cfg(feature = "vgmstream")]
    {
        let mut decoder = WemDecoder::new();
        let samples = decoder.decode_file(_wem_path)?;

        let spec = hound::WavSpec {
            channels: decoder.get_channels(),
            sample_rate: decoder.get_sample_rate(),
            bits_per_sample: 16,
            sample_format: hound::SampleFormat::Int,
        };

        let mut writer = hound::WavWriter::create(_output_path, spec)
            .map_err(|e| WemError::DecodeError(e.to_string()))?;

        for sample in samples {
            writer
                .write_sample(sample)
                .map_err(|e| WemError::DecodeError(e.to_string()))?;
        }

        writer
            .finalize()
            .map_err(|e| WemError::DecodeError(e.to_string()))?;

        Ok((
            decoder.get_sample_rate(),
            decoder.get_channels(),
            decoder.get_total_samples(),
        ))
    }

    #[cfg(not(feature = "vgmstream"))]
    {
        Err(WemError::InvalidData(
            "vgmstream feature not enabled".to_string(),
        ))
    }
}

#[cfg(feature = "vgmstream")]
mod vgmstream_sys {
    include!(concat!(env!("OUT_DIR"), "/vgmstream_bindings.rs"));
}
