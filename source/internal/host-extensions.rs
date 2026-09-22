use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HostExtensionDeclaration {
    pub id: String,
    pub dependencies: Vec<String>,
}

impl HostExtensionDeclaration {
    pub fn new<I, S>(id: impl Into<String>, dependencies: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        Self {
            id: id.into(),
            dependencies: dependencies.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum HostExtensionGraphError {
    DuplicateId(String),
    SelfDependency(String),
    MissingDependency { extension: String, dependency: String },
    Cycle(Vec<String>),
}

impl fmt::Display for HostExtensionGraphError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::DuplicateId(id) => write!(formatter, "two host extensions declare the id \"{id}\""),
            Self::SelfDependency(id) => write!(formatter, "host extension \"{id}\" declares itself as a peer"),
            Self::MissingDependency { extension, dependency } => write!(
                formatter,
                "host extension \"{extension}\" requires the peer \"{dependency}\", which is not in this build"
            ),
            Self::Cycle(path) => write!(formatter, "host extension peer cycle: {}", path.join(" -> ")),
        }
    }
}

impl std::error::Error for HostExtensionGraphError {}

pub fn resolve_host_extension_boot_order(
    extensions: &[HostExtensionDeclaration],
) -> Result<Vec<String>, HostExtensionGraphError> {
    let mut peers = BTreeMap::<String, BTreeSet<String>>::new();
    for extension in extensions {
        if peers.contains_key(&extension.id) {
            return Err(HostExtensionGraphError::DuplicateId(extension.id.clone()));
        }
        peers.insert(
            extension.id.clone(),
            extension.dependencies.iter().cloned().collect(),
        );
    }

    for extension in extensions {
        for dependency in &extension.dependencies {
            if dependency == &extension.id {
                return Err(HostExtensionGraphError::SelfDependency(extension.id.clone()));
            }
            if !peers.contains_key(dependency) {
                return Err(HostExtensionGraphError::MissingDependency {
                    extension: extension.id.clone(),
                    dependency: dependency.clone(),
                });
            }
        }
    }

    let mut remaining = peers.keys().cloned().collect::<Vec<_>>();
    let mut started = BTreeSet::<String>::new();
    let mut order = Vec::with_capacity(remaining.len());
    while !remaining.is_empty() {
        let index = remaining.iter().position(|id| {
            peers
                .get(id)
                .into_iter()
                .flatten()
                .all(|dependency| started.contains(dependency))
        });
        let Some(index) = index else {
            return Err(HostExtensionGraphError::Cycle(describe_cycle(&peers, &started)));
        };
        let id = remaining.remove(index);
        started.insert(id.clone());
        order.push(id);
    }
    Ok(order)
}

fn describe_cycle(
    peers: &BTreeMap<String, BTreeSet<String>>,
    started: &BTreeSet<String>,
) -> Vec<String> {
    fn walk(
        id: &str,
        peers: &BTreeMap<String, BTreeSet<String>>,
        started: &BTreeSet<String>,
        path: &mut Vec<String>,
    ) -> Option<Vec<String>> {
        if let Some(index) = path.iter().position(|item| item == id) {
            let mut cycle = path[index..].to_vec();
            cycle.push(id.to_string());
            return Some(cycle);
        }
        path.push(id.to_string());
        if let Some(dependencies) = peers.get(id) {
            for dependency in dependencies {
                if started.contains(dependency) {
                    continue;
                }
                if let Some(cycle) = walk(dependency, peers, started, path) {
                    return Some(cycle);
                }
            }
        }
        path.pop();
        None
    }

    for id in peers.keys().filter(|id| !started.contains(*id)) {
        if let Some(cycle) = walk(id, peers, started, &mut Vec::new()) {
            return cycle;
        }
    }
    peers
        .keys()
        .filter(|id| !started.contains(*id))
        .cloned()
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolves_dependencies_before_dependents() {
        let extensions = vec![
            HostExtensionDeclaration::new("gateway", ["auth"]),
            HostExtensionDeclaration::new("auth", std::iter::empty::<&str>()),
            HostExtensionDeclaration::new("tools", ["gateway"]),
        ];
        assert_eq!(
            resolve_host_extension_boot_order(&extensions).unwrap(),
            vec!["auth", "gateway", "tools"]
        );
    }

    #[test]
    fn rejects_missing_dependency_and_cycles() {
        let missing = vec![HostExtensionDeclaration::new("gateway", ["auth"])];
        assert!(matches!(
            resolve_host_extension_boot_order(&missing),
            Err(HostExtensionGraphError::MissingDependency { .. })
        ));

        let cycle = vec![
            HostExtensionDeclaration::new("a", ["b"]),
            HostExtensionDeclaration::new("b", ["a"]),
        ];
        assert!(matches!(
            resolve_host_extension_boot_order(&cycle),
            Err(HostExtensionGraphError::Cycle(_))
        ));
    }
}
