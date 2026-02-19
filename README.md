# mu-loader

Composer 2 plugin for WordPress that generates a single MU-plugin loader file from one or more configured folders.

## Install

```bash
composer require zombie-flesh-eaters/mu-loader
```

## How it works

On Composer autoload dump (`install`, `update`, or `dump-autoload`), this package:

1. Scans configured MU-plugin folders for `.php` files (recursively).
2. Writes a generated loader file with `require_once` statements.

Default output file:

- `wp-content/mu-plugins/000-mu-loader.php`

## Configuration

Set config in your project `composer.json` under `extra.mu-loader`.

```json
{
  "extra": {
    "mu-loader": {
      "paths": [
        "wp-content/mu-plugins",
        "web/app/mu-plugins"
      ],
      "output": "wp-content/mu-plugins/000-mu-loader.php",
      "exclude": [
        "wp-content/mu-plugins/some-file-to-skip.php"
      ]
    }
  }
}
```

### Options

- `paths` (`string|array`, default: `["wp-content/mu-plugins"]`)
- `output` (`string`, default: first existing path + `/000-mu-loader.php`)
- `exclude` (`string|array`, default: `[]`) absolute or relative file paths to skip

## Notes

- The output file is generated; manual edits are overwritten.
- Only existing directories in `paths` are scanned.

## Testing

Run the integration test:

```bash
composer run test:integration
```
