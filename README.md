# EXPath-Task-XSLT
Implementation of EXPath Tasks in pure portable XSLT 3.0.

This is a reference implementation for our paper [Task Abstraction for XPath Derived Languages. Lockett and Retter, 2019]() which was presented at [XML Prague](http://www.xmlprague.cz) 2019.

It is worth explicitly restating that this implementation does not provide asynchronous processing, instead all asynchrnous functions will be executed synchronously.

## Using
Download the [`task.xsl`]() file for use with your favourite XPDL processor.

From your main XSLT stylesheet simply import the module like so, adjusting the value of the `href` attribute as necessary:

```xslt
<xsl:import href="task.xsl"/>
```

And add the required namespace declarations:

```xslt
xmlns:task="http://expath.org/ns/task"
xmlns:adt="http://expath.org/ns/task/adt"
```

## Examples

See the [`task-examples.xsl`]() file for various examples. These can be run independently by running the stylesheet with
different initial templates (`exA1`, `exA1.1`, and so on) for the different tests. For example supply `-xsl:task-examples.xsl -it:exA1` to run Example 1.
