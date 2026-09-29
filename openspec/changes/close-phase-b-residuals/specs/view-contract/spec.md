## ADDED Requirements

### Requirement: A view explains the host-tool authentication method

The system SHALL generate, for every interface whose authentication method is
`host-tool`, a fixed explanation that a tool already signed in on the machine
carries the credential, in both the view an agent reads and the rendering a
person reads. The explanation is framework text, identical for every document.

#### Scenario: An agent reading a view learns what host-tool means

- **WHEN** an Org document declares an interface with `auth.method: host-tool`
  and its view is generated
- **THEN** that interface's `auth` object in `view.yaml` carries the explanation,
  and its Auth line in `view.md` carries the same text

#### Scenario: Other methods render as before

- **WHEN** an interface declares any other authentication method
- **THEN** its `auth` object carries no explanation field and its rendering is
  unchanged
