use crate::extension_ids_generated::TURN_EXECUTION;
use crate::host_extensions::{
    HostExtensionRuntimeDeclaration, define_host_extension,
};
use crate::turn_execution_service::TurnExecutionRegistry;

pub fn turn_execution_extension<Host>() -> HostExtensionRuntimeDeclaration<Host>
where
    Host: Send + Sync + 'static,
{
    define_host_extension(
        TURN_EXECUTION,
        std::iter::empty::<&str>(),
        |_context| async { Ok::<_, String>(TurnExecutionRegistry::new()) },
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::host_extensions::start_host_extensions;
    use std::sync::Arc;

    #[tokio::test]
    async fn extension_starts_registry_under_generated_extension_id() {
        let extension = turn_execution_extension::<()>();
        assert_eq!(extension.declaration.id, TURN_EXECUTION);
        assert!(extension.declaration.dependencies.is_empty());

        let mut started = start_host_extensions(
            &[extension],
            Arc::new(()),
            |_extension_id, _error| {},
        )
        .await
        .unwrap();
        let registry = started
            .api::<TurnExecutionRegistry>(TURN_EXECUTION)
            .expect("turn execution registry");
        assert!(!registry.can_execute());
        started.stop().await;
    }
}
