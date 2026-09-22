use std::io;
use std::path::{Component, Path, PathBuf};

#[derive(Debug)]
pub enum ProtectedPathError {
    Protected(String),
    Io(io::Error),
}

impl std::fmt::Display for ProtectedPathError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Protected(message) => formatter.write_str(message),
            Self::Io(error) => error.fmt(formatter),
        }
    }
}

impl std::error::Error for ProtectedPathError {}

pub fn refusal_message(path: &Path) -> String {
    format!(
        "Path is inside a protected host-only store and was refused: {}",
        path.display()
    )
}

fn normalize_lexically(path: &Path) -> PathBuf {
    let mut result = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                result.pop();
            }
            other => result.push(other.as_os_str()),
        }
    }
    result
}

fn is_path_within(root: &Path, candidate: &Path) -> bool {
    candidate == root || candidate.starts_with(root)
}

fn canonicalize_nearest_existing(path: &Path) -> io::Result<PathBuf> {
    let mut probe = path.to_path_buf();
    let mut tail = Vec::new();

    while !probe.exists() {
        let Some(name) = probe.file_name().map(|value| value.to_os_string()) else {
            break;
        };
        tail.push(name);
        if !probe.pop() {
            break;
        }
    }

    let mut resolved = if probe.exists() {
        probe.canonicalize()?
    } else {
        normalize_lexically(path)
    };
    for component in tail.into_iter().rev() {
        resolved.push(component);
    }
    Ok(normalize_lexically(&resolved))
}

pub fn assert_path_outside_protected_roots(
    protected_roots: &[PathBuf],
    candidate_path: &Path,
    base_dir: &Path,
) -> Result<(), ProtectedPathError> {
    if protected_roots.is_empty() {
        return Ok(());
    }

    let resolved = normalize_lexically(if candidate_path.is_absolute() {
        candidate_path.to_path_buf()
    } else {
        base_dir.join(candidate_path)
    });

    for root in protected_roots {
        let root = normalize_lexically(root);
        if is_path_within(&root, &resolved) {
            return Err(ProtectedPathError::Protected(refusal_message(
                candidate_path,
            )));
        }
    }

    let real_resolved =
        canonicalize_nearest_existing(&resolved).map_err(ProtectedPathError::Io)?;
    for root in protected_roots {
        let real_root =
            canonicalize_nearest_existing(root).map_err(ProtectedPathError::Io)?;
        if is_path_within(&real_root, &real_resolved) {
            return Err(ProtectedPathError::Protected(refusal_message(
                candidate_path,
            )));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_direct_and_parent_traversal_into_protected_root() {
        let root = std::env::temp_dir().join("fabushi-protected-root");
        assert!(matches!(
            assert_path_outside_protected_roots(
                std::slice::from_ref(&root),
                &root.join("secret.db"),
                Path::new("/")
            ),
            Err(ProtectedPathError::Protected(_))
        ));
        assert!(matches!(
            assert_path_outside_protected_roots(
                std::slice::from_ref(&root),
                Path::new("../fabushi-protected-root/secret.db"),
                &root.join("public")
            ),
            Err(ProtectedPathError::Protected(_))
        ));
    }

    #[test]
    fn allows_unrelated_paths() {
        let root = std::env::temp_dir().join("fabushi-protected-root");
        let other = std::env::temp_dir().join("fabushi-public-root/file.txt");
        assert!(
            assert_path_outside_protected_roots(
                &[root],
                &other,
                Path::new("/")
            )
            .is_ok()
        );
    }

    #[cfg(unix)]
    #[test]
    fn rejects_symlink_escape_into_protected_root() {
        use std::os::unix::fs::symlink;

        let base = std::env::temp_dir().join(format!(
            "fabushi-path-guard-{}",
            std::process::id()
        ));
        let protected = base.join("protected");
        let public = base.join("public");
        let link = public.join("alias");
        let _ = std::fs::remove_dir_all(&base);
        std::fs::create_dir_all(&protected).unwrap();
        std::fs::create_dir_all(&public).unwrap();
        symlink(&protected, &link).unwrap();

        let result = assert_path_outside_protected_roots(
            std::slice::from_ref(&protected),
            &link.join("secret.db"),
            &public,
        );
        let _ = std::fs::remove_dir_all(&base);
        assert!(matches!(result, Err(ProtectedPathError::Protected(_))));
    }
}
