const OPEN_TAG: &str = "<system_reminder>";
const CLOSE_TAG: &str = "</system_reminder>";

pub fn sanitize_system_reminder_content(content: &str) -> String {
    let bytes = content.as_bytes();
    let mut output = String::with_capacity(content.len() + 8);
    let mut last = 0usize;
    let mut index = 0usize;

    while index < bytes.len() {
        let remaining = &content[index..];
        if remaining.len() >= CLOSE_TAG.len()
            && remaining[..CLOSE_TAG.len()].eq_ignore_ascii_case(CLOSE_TAG)
        {
            output.push_str(&content[last..index]);
            output.push_str("</system_reminder_>");
            index += CLOSE_TAG.len();
            last = index;
            continue;
        }
        if remaining.len() >= OPEN_TAG.len()
            && remaining[..OPEN_TAG.len()].eq_ignore_ascii_case(OPEN_TAG)
        {
            output.push_str(&content[last..index]);
            output.push_str("<system_reminder_>");
            index += OPEN_TAG.len();
            last = index;
            continue;
        }
        index += content[index..].chars().next().map(char::len_utf8).unwrap_or(1);
    }

    output.push_str(&content[last..]);
    output
}

#[cfg(test)]
mod tests {
    use super::sanitize_system_reminder_content;

    #[test]
    fn neutralizes_open_and_close_tags_case_insensitively() {
        assert_eq!(
            sanitize_system_reminder_content(
                "a<SYSTEM_REMINDER>x</System_Reminder>b<system_reminder>y"
            ),
            "a<system_reminder_>x</system_reminder_>b<system_reminder_>y"
        );
    }

    #[test]
    fn leaves_non_matching_text_unchanged() {
        assert_eq!(sanitize_system_reminder_content("系统 reminder"), "系统 reminder");
    }
}
