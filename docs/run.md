# Running Ports on Device

## Background
One of the goals of PortMaster is to ensure that everything is included in the zip that is needed for a given port (libs, script to run, etc).  One problem with this technically is that there's a lot of duplication across zip files (device detection, common libraries).  This means that supporting new devices or fixing bugs in many zips is **hard**.

## Deduplication

One approach that has simplified things greatly is using `control.txt`.  This is a huge improvement, but does have a drawback that the port now depends on the current version of portmaster.

Using a build system, we can now easily have files which are included in all ports.  This means we can deduplicate a lot of the code and even include control.txt, etc.

There may be additional simplification of control.txt as well.

## Goals
- Ports should ideally have no *device specific* code in their scripts.  This means that new, similar devices can be added without additional code in each port.
  - In places where device specific code would be used, some intermediate variable should be used instead.  For example: resolution or number of analog sticks.  This way, unless a device has something novel (a new resolution, etc) which the port needs to account for, it can be updated seamlessly. 
- Ports should have as little OS specific code in their scripts as possible.  Typically, only for things like additional libraries needed.

## global-functions

`control.txt` is a great step forward for reuse, but there are still cases where: 1. `control.txt` can't ecapsulate everything the port script needs to do. 2. `control.txt` needs better ways to be tested and kept simple as more and more things are added to it.

In these cases, `global-functions` can help.  Basically,`global-functions` can be sourced without any change and then has individual methods for things like `get_os`, `get_device`, etc.  These functions contain either *no* global variables or variables that start with `__` so they are unlikely to be inadvertantly used by other scripts.  Tests can be written in [bats](https://github.com/bats-core/bats-core) to ensure tricky things like device/OS detection are correct once verified.

See documentation in [portmaster](../ports/portmaster/README.md) and [global](../ports/global/README.md)