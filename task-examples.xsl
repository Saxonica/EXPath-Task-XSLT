<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fn="http://www.w3.org/2005/xpath-functions"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:err="http://www.w3.org/2005/xqt-errors"
  xmlns:task="http://expath.org/ns/task"
  xmlns:adt="http://expath.org/ns/task/adt"
  xmlns:local="http://functions/local"
  exclude-result-prefixes="#all"
  version="3.0">
  
  <xsl:import href="task.xsl"/>
  
  <!-- XSLT examples using EXPath Tasks.
       Run the different tests by supplying the initial template for a transform. -->
  
  
  <!-- A. Constructing Tasks -->
  
  <!-- 1. Create a task from a pure value and run it -->
  <xsl:template name="exA1">
    <xsl:sequence select="task:RUN-UNSAFE(task:value(1234))"/>
  </xsl:template>
  
  <!-- 1.1. Create a task from a pure value and run it (fluent syntax) -->
  <xsl:template name="exA1.1">
    <xsl:sequence select="task:value('123') ? RUN-UNSAFE()"/>
  </xsl:template>
  
  <!-- 2. Create a task from a function and run it -->
  <xsl:template name="exA2">
    <xsl:sequence select="task:RUN-UNSAFE(task:of(function() { 1 + 2 }))"/>
  </xsl:template>
  
  <!-- 2.1. Create a task from a function and run it (fluent syntax) -->
  <xsl:template name="exA2.1">
    <xsl:sequence select="task:of(function() { 1 + 2 }) ? RUN-UNSAFE()"/>
  </xsl:template>
  
  
  <!-- B. Composing Tasks -->
  
  <!-- 1. Using bind to transform a value -->
  <xsl:template name="exB1">
    <xsl:sequence select="task:value(123)
      ? bind(function($i) { task:value($i || 'val1') })
      ? bind(function($i) { task:value($i || 'val2') })
      ? RUN-UNSAFE()"/>
  </xsl:template>
  
  <!-- 2. Using fmap to perform a function -->
  <xsl:template name="exB2">
    <xsl:sequence select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' adam'))
      ? RUN-UNSAFE()"/>
  </xsl:template>
  
  <!-- 3. Composing two tasks with bind -->
  <!-- 3.1. You should **never** have more than one call to RUN-UNSAFE, i.e. **DO NOT DO THIS** -->
  <xsl:template name="exB3.1">
    <xsl:sequence select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))
      ? RUN-UNSAFE()
      ,
      task:value('goodbye')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 3.2 Instead, you can compose the tasks with bind -->
  <xsl:template name="exB3.2">
    <xsl:sequence select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))
      ? bind(function($hello) {
        task:value('goodbye')
          ? fmap(upper-case#1)
          ? fmap(concat(?, ' debbie'))
          ? fmap(function($goodbye) {($hello, $goodbye)})
      })
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 3.3 The longer form if you like variable bindings -->
  <xsl:template name="exB3.3">
    <xsl:variable name="task-hello" select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))"/>
    <xsl:variable name="task-goodbye" select="task:value('goodbye')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))"/>
    <xsl:sequence select="$task-hello
      ? bind(function($hello){
        $task-goodbye
          ? fmap(function($goodbye){
            ($hello, $goodbye)})})
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 3.4. Or alternatively shorter syntax by partially applying fn:insert-before -->
  <xsl:template name="exB3.4">
    <xsl:sequence select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))
      ? bind(function($hello) {
        task:value('goodbye')
          ? fmap(upper-case#1)
          ? fmap(concat(?, ' debbie'))
          ? fmap(fn:insert-before(?, 0, $hello))
      })
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 3.5. Or if you need an array instead of a sequence to preserve isolation of the results -->
  <xsl:template name="exB3.5">
    <xsl:sequence select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))
      ? bind(function($hello) {
        task:value('goodbye')
          ? fmap(upper-case#1)
          ? fmap(concat(?, ' debbie'))
          ? fmap(function($goodbye) {[$hello, $goodbye]})
      })
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 3.6. Or alternatively shorter syntax by partially applying array:append -->
  <xsl:template name="exB3.6">
    <xsl:sequence select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))
      ? bind(function($hello) {
        task:value('goodbye')
          ? fmap(upper-case#1)
          ? fmap(concat(?, ' debbie'))
          ? fmap(array:append([$hello], ?))
      })
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 3.7. The longer form for returning an array if you like variable bindings -->
  <xsl:template name="exB3.7">
    <xsl:variable name="task-hello" select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))"/>
    <xsl:variable name="task-goodbye" select="task:value('goodbye')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))"/>
    <xsl:sequence select="$task-hello
      ? bind(function($hello){
        $task-goodbye
          ? fmap(function($goodbye){
            [$hello, $goodbye]})})
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 4.1. Composing two or more tasks with sequence; using the task:sequence function syntax-->
  <xsl:template name="exB4.1">
    <xsl:variable name="task-hello" select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))"/>
    <xsl:variable name="task-goodbye" select="task:value('goodbye')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))
      ? fmap(fn:tokenize(?, ' '))
      ? fmap(array:append([], ?))"/>
    <xsl:sequence select="task:sequence(($task-hello, $task-goodbye))
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 4.2. Using the sequence fluent syntax-->
  <xsl:template name="exB4.2">
    <xsl:variable name="task-hello" select="task:value('hello')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))"/>
    <xsl:variable name="task-goodbye" select="task:value('goodbye')
      ? fmap(upper-case#1)
      ? fmap(concat(?, ' debbie'))
      ? fmap(fn:tokenize(?, ' '))
      ? fmap(array:append([], ?))"/>
    <xsl:sequence select="$task-hello
      ? sequence($task-goodbye)
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  
  <!-- C. Asynchronous Tasks
  Remember that an "Async" is just a reference to an asynchronous computation. -->
  
  <!-- 1. Asynchronously executing a task where you don't care about the result -->
  <xsl:template name="exC1">
    <xsl:variable name="some-task" select="task:value('hello')
      ? fmap(upper-case#1)
      ? async()"/>
    <xsl:variable name="result" select="$some-task ? RUN-UNSAFE() "/>
    <xsl:sequence select="$result instance of function(*)"/>
  </xsl:template>
  
  <!-- 2. Asynchronously executing a task, when you do care about the result, you have to wait upon the asynchronous
    computation -->
  <xsl:template name="exC2">
    <xsl:sequence select="task:value('hello')
      ? fmap(upper-case#1)
      ? async() 
      ? bind(task:wait#1)
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 3. Asynchronous equivalent to fork-join, where you don't care about the results -->
  <xsl:function name="local:char-to-int" as="xs:integer">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="fn:string-to-codepoints($s)[1]"/>
  </xsl:function>
  <xsl:function name="local:int-to-char" as="xs:string">
    <xsl:param name="i" as="xs:integer"/>
    <xsl:sequence select="fn:substring(fn:codepoints-to-string($i), 1, 1)"/>
  </xsl:function>
  <xsl:function name="local:square" as="xs:integer">
    <xsl:param name="i" as="xs:integer"/>
    <xsl:sequence select="$i * $i"/>
  </xsl:function>
  <xsl:template name="exC3">
    <xsl:variable name="async-task1" select="task:of(function(){ 1 to 10 })
      ? fmap(function($ii) { $ii ! local:square(.) })
      ? async()"/>
    <xsl:variable name="async-task2" select="task:of(function(){ local:char-to-int('a') to local:char-to-int('z') })
      ? fmap(function($ii) { $ii ! (. - 32) })
      ? fmap(function($ii) { $ii ! local:int-to-char(.)})
      ? async()"/>
    <xsl:variable name="result" select="$async-task1
      ? sequence($async-task2)
      ? RUN-UNSAFE() "/>
    <xsl:sequence select="$result instance of function(*)"/>
  </xsl:template>
  
  <!-- 4. Asynchronous equivalent to fork-join, where you do care about the results using task:wait-all -->
  <xsl:template name="exC4">
    <xsl:variable name="async-task1" select="task:of(function(){ 1 to 10 })
      ? fmap(function($ii) { $ii ! local:square(.) })
      ? async()"/>
    <xsl:variable name="async-task2" select="task:of(function(){ local:char-to-int('a') to local:char-to-int('z') })
      ? fmap(function($ii) { $ii ! (. - 32) })
      ? fmap(function($ii) { $ii ! local:int-to-char(.)})
      ? async()"/>
    <xsl:sequence select="$async-task1 ?sequence($async-task2)
      ? bind(task:wait-all#1)
      ? RUN-UNSAFE() "/>
  </xsl:template>
  
  <!-- 5. Cancelling an asynchronous computation, and then starting another asynchronous computation -->
  <xsl:template name="exC5">
    <xsl:sequence select="task:value('hello')
      ? fmap(upper-case#1)
      ? async() 
      ? bind(task:cancel#1)
      ? then(task:of(function(){ (1 to 10 )}))
      ? async()
      ? bind(task:wait#1)
      ? RUN-UNSAFE() "/>
  </xsl:template>

  
</xsl:stylesheet>
