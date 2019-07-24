# SOVA-SCAN - Ofuscated code detection script.

This Bash script scans a target filesystem and builds a database of files with unusual properties that might indicate the presence of obfuscated code. Output is in the form of a MySQL flatfile for easy import and analysis. This script DOES NOT definitively identify or classify anything-- it's strictly an intelligence-gathering tool.

This script uses system utilities that should be available on virtually any modern Linux distro and  should be relatively easy to adapt for use on *BSD or other Unix-like systems.

## Some Things To Know

Be aware that this script is barely more than a prototype and not terribly efficient. It has performed well on even large filesystems, but more testing is needed to catch lingering problems.

'ent' is a dependency but not a standard utility (see Prerequisites, below). In a pinch, this can be replaced by Perl, awk or Python scripts with similar functionality at the expense of performance in the event installing 'ent' is a no-go.

A tweaked "find-for" loop has been used to target specific files by extension in order reduce the size of the resulting dataset and improve performance. Blanket scans are better left to other tools like 'clamav' and 'maldet'.

This script shows how difficult it can be fully automated this kind of process-- some things are just best left to Mark 1 Analog Optical Interfaces (aka the human mind and eyes).

## Getting Started

To kick off a quick scan and drop the results to a timestamped file, try something like:

```
$ ./sova-scan.sh -d /opt/gmti > $(hostname).$(date "+%Y%m%d.%H%M%S").sql
```

This will create a MySQL flat file with database and table schema attached. You may, of course, alter the database and table names to fit your own purposes with a simple script edit.

## Prerequisites

Fourmilab's 'ent' tool: This utility is typically available in standard repos for most Linux/BSD distributions, but you may download and compile from source if you prefer. See: (http://www.fourmilab.ch/random/)

This script has been testing on Bash 2.x and up and should be easy to adapt for other command shells (Dash, CSH, ZSH, etc.).

You will also need a MySQL installation into which you may write the contents of any flat file you create using this script.

## Installing

As this just a shell script, there is no installation process, per se. However, super-user privileges are needed in order to side-step permissions issues.

## How to Analyze Results

Once imported, sifting through SOVA-SCAN results is merely MySQL queries.

Intentionally obfuscated or compressed code (not all of which is malicious) shows some distinct patterns:

* 'l_string' values that are over 1000 (often over 10000). There are valid use cases for very long, unbroken strings, but being suspicious of such things is a good idea.
* 'entropy' values for most source code and text files are typically around 5.2. Entropy values above 5.7 or below 3.8 should definitely be regarded with suspicion and examined.
* Odd or out-of-place filenames stand out; many Bad Guys (tm) seem to have an almost pathological need to use unusual or nonesensical filenames.

These guidelines are not set in stone! Try to be flexible with your searches and remember that what I write here should never be regarded as gospel. This is a subjective tool and needs to be used in a subjective way.

Example query via MySQL command-line interface:

```
select record_id,host,file_path,l_string,entropy
  from sova_scan.files
  where (entropy > 3.8 and entropy < 5.7)
    and l_string > 1024
    and (file_path like "%.php" or file_path like "%.js" or file_path like "%.py")
    and host like "%example.com%";
```

As simple queries against a single table, it's very easy to customize your searches, as needed.

## Gotcha's

Some effort has been made to cope with some of the more common file naming silliness that one often runs into. Be advised that the re-write rules used are hardly fool-proof.

## Improvements

Running this script against network filesystems means living with a heavily I/O-bound process. But for use on local file systems with far greater bandwidth and possibly multi-core CPU's available, it becomes clear that there's room for significant improvement.

If you're clever, this script can be adapted for use with GNU Parallel or similar tools. Note: Please don't try this with 'xargs'-- it's fragile and lacks a number of important features.

If you're especially clever, you could try adapting the concepts in this script to some flavor of heuristic analysis or machine learning techniques? If you go down that road, be sure to avail yourself of tools like CUDA, OpenCL and/or OpenMT in conjection with platforms like Caffe, TensorFlow or ArrayFire. I would also suggest you read up on how the Bad Guys (tm) have been trying to defeat such analysis; mostly by tricking AI's with intentionally bad or misleading data for the purpose of subverting legitimate training models.

## Author

**Rick Pelletier** - rpelletier@gannett.com

## License

Copyright (C) 2016, Richard Pelletier

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Acknowledgments

Thanks to Neohapsis for some early work on this concept. (https://github.com/Neohapsis/NeoPI)

## Trivia

The word "sova" is Czechoslovakian for "owl".
