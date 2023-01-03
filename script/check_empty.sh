#!/bin/bash
[ -s custom_errors.log ] && echo "There were errors when compiling with latex!" && exit 1 || echo "No errors or warnings found by regex."

