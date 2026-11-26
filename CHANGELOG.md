# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- An `index_name:` option on `rescue_from_duplicate` and inside `rescue_from_duplicate: { index_name: }` on a
  uniqueness validation, taking one index name or an array of names. The handler that names the violated index is
  used even when the index columns differ from the declaration, and `missing_unique_indexes` accepts a named unique
  index as well as one with matching columns.

### Fixed

- `missing_unique_indexes` no longer raises `NoMethodError` on a table that has an expression unique index
  (`lower(email)`), whose columns Active Record reports as a String.

## [0.2.7] - 2026-08-26

### Fixed

- It was possible that the gem wouldn't rescue a unique constraint violation error in
  the even that a non unique index name would match a subset of the unique index
  to rescue.
