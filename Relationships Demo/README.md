# Boutique Relationships Demo

This app is a focused test bed for Boutique Store relationships.

It lets you create `Note` and `Tag` records, link tags to notes by selecting a tag and tapping a note, and then exercise relationship propagation:

- Updating a tag cascades into `Note.tags` and `Note.primaryTag`.
- Removing a tag clears it from `Note.tags`.
- Removing a tag nullifies `Note.primaryTag`.
- Removing a note does not affect tags.

Every user action logs to the console with the format `[Current-Timestamp] Action:`. The toolbar JSON button prints a formatted snapshot of the current notes and tags and copies it to the pasteboard for debugging.

### License

See the [license](../LICENSE) for more information about how you can use Boutique.
