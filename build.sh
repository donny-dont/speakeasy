set -e

pub install

pub global activate linter
pub global run linter .
