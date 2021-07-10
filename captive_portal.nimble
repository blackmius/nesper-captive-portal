# Package

version       = "0.1.0"
author        = "d.terlyakhin"
description   = "A new awesome nimble package"
license       = "MIT"


# Dependencies

requires "nim >= 1.4.6"

requires "nesper >= 0.6.1"
# includes nimble tasks for building Nim esp-idf projects
include nesper/build_utils/tasks
