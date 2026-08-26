# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.7] - 2026-08-26

### Fixed

- It was possible that the gem wouldn't rescue a unique constraint violation error in
  the even that a non unique index name would match a subset of the unique index
  to rescue.
