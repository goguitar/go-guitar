use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    // Check if vgmstream headers exist before running bindgen
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let vgmstream_h = manifest_dir
        .join("ext")
        .join("vgmstream")
        .join("src")
        .join("vgmstream.h");
    let streamfile_h = manifest_dir
        .join("ext")
        .join("vgmstream")
        .join("src")
        .join("streamfile.h");

    if vgmstream_h.exists() && streamfile_h.exists() {
        println!("cargo:rerun-if-changed={}", vgmstream_h.display());
        println!("cargo:rerun-if-changed={}", streamfile_h.display());

        let out_dir = env::var("OUT_DIR").unwrap();
        let dest_path = PathBuf::from(out_dir);

        // Create placeholder bindings file
        let placeholder = r#"
use std::ffi::c_void;

#[repr(C)]
pub struct VGMSTREAM {
    _private: [u8; 0],
}

#[repr(C)]
pub struct STREAMFILE {
    _private: [u8; 0],
}

extern "C" {
    pub fn init_vgmstream_from_stdio(filename: *const i8) -> *mut VGMSTREAM;
    pub fn init_vgmstream_from_streamfile(sf: *mut STREAMFILE) -> *mut VGMSTREAM;
    pub fn close_vgmstream(vgmstream: *mut VGMSTREAM);
    pub fn render_vgmstream2(buffer: *mut i16, sample_count: i32, vgmstream: *mut VGMSTREAM) -> i32;
    pub fn seek_vgmstream(vgmstream: *mut VGMSTREAM, seek_sample: i32);
}
"#;

        fs::write(dest_path.join("vgmstream_bindings.rs"), placeholder).ok();
        println!("cargo:warning=vgmstream headers found but bindgen not available - using placeholder bindings");
    } else {
        println!("cargo:warning=vgmstream headers not found - skipping bindgen");
        println!("cargo:rerun-if-changed=build.rs");
    }
}
