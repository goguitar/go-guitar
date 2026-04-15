mod wem;
mod audio;
#[cfg(feature = "rocksmith")]
mod psarc;
#[cfg(feature = "rocksmith")]
mod arrangement;

#[cfg(feature = "rocksmith")]
pub use psarc::DlcLoader;
pub use audio::AudioMixer;
pub use wem::WemDecoder;

#[cfg(feature = "rocksmith")]
pub mod godot_export {
    pub use super::audio::AudioMixer;
    pub use super::wem::WemDecoder;
    pub use super::psarc::DlcLoader;
}

#[cfg(not(feature = "rocksmith"))]
pub mod godot_export {
    pub use super::audio::AudioMixer;
    pub use super::wem::WemDecoder;
}

#[cfg(not(feature = "rocksmith"))]
#[allow(dead_code)]
mod stub_psarc;
