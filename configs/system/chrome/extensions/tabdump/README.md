# Tabdump

A minimal Google Chrome extension that copies all URLs from the active tab
group to the clipboard, one URL per line.

## Install

1. Extract `tabdump-1.1.0.zip`.
2. Open `chrome://extensions/`.
3. Enable **Developer mode**.
4. Remove the previous Tabdump version, or point the existing unpacked extension
   at the new directory.
5. Click **Load unpacked**.
6. Select the extracted `tabdump-1.1.0` directory.
7. Pin Tabdump to the toolbar.

## Use

1. Activate any tab in the group you want to export.
2. Click the Tabdump toolbar icon.
3. Paste the copied URLs.

## Feedback

After a successful copy:

- the toolbar icon changes from a copy icon to a copy/check icon for two seconds;
- the badge briefly shows how many URLs were copied.

Errors:

- `NO`: the active tab is not in a tab group;
- `ERR`: an unexpected error occurred.

## Output

```text
https://example.com/one
https://example.com/two
https://example.com/three
```

No data is transmitted anywhere.
