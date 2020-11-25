0.2.4 (2020-11-25)
==================

- use `Base64.strict_encode64` instead of `Base64.encode64` to circumvent problems line feeds

0.2.3 (2020-06-24)
==================

- do not require json response for status check

0.2.2 (2019-11-26)
==================

- added response code test

0.2.1 (2019-11-19)
==================

- ERB evaluation for body

0.2.0 (2019-11-19)
==================

- added support for multipart/form-data and file upload
- added new time format :iso8601utc

0.1.5 (2019-07-04)
==================

- extended response() to get access to jobs in other groups in same project
- added response code to report

0.1.4 (2019-07-03)
==================

- added credential and basicauth function
- changed regex for job selection
- ERB evaluation for authorization, vars
- colorize output

0.1.3 (2018-12-13)
==================

- introduce environments for Domain and Authorization settings

0.1.2 (2018-12-03)
==================

- request writer
- extended var() function with default and ignore\_error

0.1.1 (2018-10-12)
==================

- use overlay\_config library
- added --quiet argument, which suppress most output
- fix generate\_json\_file
- added --generate-report, which generates a report csv in output directory

0.1.0 (2018-10-04)
==================

- Initial release
