#[[
  This file is provided under the BSD Zero Clause License.

  Permission to use, copy, modify, and/or distribute this software for any
  purpose with or without fee is hereby granted.

  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
  REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
  AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
  INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
  LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
  OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
  PERFORMANCE OF THIS SOFTWARE.
]]

#
# Store variables as files so that they can later be read independently by other tools
#
# Functions:
#
#   write_config_info (DIRECTORY <dir> VARIABLES <var>...)
#       For each variable writes a file with the name and the content of the
#       variable to the specified directory.
#       The DIRECTORY path must be absolute.
#

function (write_config_info)
  cmake_parse_arguments (PARSE_ARGV 0 "WRITE_CONFIG_INFO" "" "DIRECTORY" "VARIABLES")

  if (DEFINED WRITE_CONFIG_INFO_UNPARSED_ARGUMENTS)
    message (FATAL_ERROR "Unrecognized arguments: ${WRITE_CONFIG_INFO_UNPARSED_ARGUMENTS}")
  endif ()

  if (DEFINED WRITE_CONFIG_INFO_KEYWORDS_MISSING_VALUES)
    if ("DIRECTORY" IN_LIST WRITE_CONFIG_INFO_KEYWORDS_MISSING_VALUES)
      message (FATAL_ERROR "No directory specified")
    endif ()
    if ("VARIABLES" IN_LIST WRITE_CONFIG_INFO_KEYWORDS_MISSING_VALUES)
      message (WARNING "No variables specified")
    endif ()
  endif ()

  if (NOT IS_ABSOLUTE ${WRITE_CONFIG_INFO_DIRECTORY})
    message (FATAL_ERROR "Directory must be specified as an absolute path. Got \"${WRITE_CONFIG_INFO_DIRECTORY}\"")
    # ... otherwise behavior of some path operations might not be well-defined.
  endif ()

  set (COMMENT_FILE "${WRITE_CONFIG_INFO_DIRECTORY}/#The contents of this directory are generated by CMake!")

  if (EXISTS ${COMMENT_FILE})
    # Assume this directory was generated by this function and it's fine to delete it.
    file (REMOVE_RECURSE ${WRITE_CONFIG_INFO_DIRECTORY})
  elseif (IS_DIRECTORY ${WRITE_CONFIG_INFO_DIRECTORY})
    message (WARNING "Might pollute existing directory with config info. To make this warning disappear, delete this directory: \"${WRITE_CONFIG_INFO_DIRECTORY}\"")
  elseif (EXISTS ${WRITE_CONFIG_INFO_DIRECTORY})
    message (FATAL_ERROR "\"${WRITE_CONFIG_INFO_DIRECTORY}\" is not a directory")
  endif ()

  if (NOT EXISTS ${WRITE_CONFIG_INFO_DIRECTORY})
    # This will also create the necessary parent directories.
    file (WRITE ${COMMENT_FILE} "Generated by CMake")
  endif ()

  message ("Writing variables to \"${WRITE_CONFIG_INFO_DIRECTORY}\":")
  foreach (VAR ${WRITE_CONFIG_INFO_VARIABLES})
    file (WRITE ${WRITE_CONFIG_INFO_DIRECTORY}/${VAR} ${${VAR}})
    message ("    ${VAR} : \"${${VAR}}\"")
  endforeach ()
endfunction ()
