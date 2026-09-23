use std::path::Path;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SelectedImageInput {
    pub data: Vec<u8>,
    pub path: String,
    pub mime_type: Option<&'static str>,
}

fn image_mime_from_path(path: &str) -> Option<&'static str> {
    let extension = Path::new(path)
        .extension()
        .and_then(|value| value.to_str())?
        .to_ascii_lowercase();
    match extension.as_str() {
        "avif" => Some("image/avif"),
        "bmp" => Some("image/bmp"),
        "gif" => Some("image/gif"),
        "ico" => Some("image/x-icon"),
        "jpeg" | "jpg" => Some("image/jpeg"),
        "png" => Some("image/png"),
        "svg" => Some("image/svg+xml"),
        "webp" => Some("image/webp"),
        _ => None,
    }
}

pub async fn load_selected_image_inputs(
    attachment_paths: &[String],
) -> Vec<SelectedImageInput> {
    let mut loaded = Vec::with_capacity(attachment_paths.len());
    for path in attachment_paths {
        let Ok(data) = tokio::fs::read(path).await else { continue; };
        loaded.push(SelectedImageInput {
            data,
            path: path.clone(),
            mime_type: image_mime_from_path(path),
        });
    }
    loaded
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[tokio::test]
    async fn loads_readable_files_and_silently_skips_missing_paths() {
        let path = std::env::temp_dir().join(format!(
            "fabushi-selected-image-{}-{}.png",
            std::process::id(),
            SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos()
        ));
        fs::write(&path, [1u8, 2, 3]).unwrap();
        let inputs = load_selected_image_inputs(&[
            path.to_string_lossy().into_owned(),
            "/definitely/missing/image.jpg".into(),
        ]).await;
        assert_eq!(inputs.len(), 1);
        assert_eq!(inputs[0].data, vec![1, 2, 3]);
        assert_eq!(inputs[0].mime_type, Some("image/png"));
        let _ = fs::remove_file(path);
    }
}
