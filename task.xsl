<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fn="http://www.w3.org/2005/xpath-functions"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:err="http://www.w3.org/2005/xqt-errors"
  xmlns:task="http://expath.org/ns/task"
  xmlns:adt="http://expath.org/ns/task/adt"
  exclude-result-prefixes="#all"
  version="3.0">
  
  <!-- Reference implementation of the EXPath Task Module written in XSLT 3.0.
    
    Based on the implementation of the EXPath Task Module written in XQuery (https://github.com/adamretter/task.xq) by
    Adam Retter.
    
    Note that with this reference implementation, any asynchronous actions will be executed synchronously!
    For a true implementation of this module which supports asynchronous execution, support is required from the XSLT
    processor.
    
    The type of a `Task` is: map(xs:string, function(*))
    
    The type of an `Async` is: function(element(adt:scheduler)) as item()+
    
    @author Debbie Lockett <debbie@saxonica.com>
  
  -->
  
  <xsl:variable name="realworldEl" as="element(adt:realworld)">
    <adt:realworld/>
  </xsl:variable>
  
  <xsl:variable name="schedulerEl" as="element(adt:scheduler)">
    <adt:scheduler/>
  </xsl:variable>
  
  <!-- Internal implementation!
    
    Creates a representation of a Task.
    @param $apply-fn This is the real task abstraction! A function that when applied to the real world, returns a (new)
      real world and the result of the task.
    @return A map which encapsulates operations that can be performed on a Task. -->
  <xsl:function name="task:create-monadic-task" as="map(*)">
    <xsl:param name="apply-fn" as="function(element(adt:realworld)) as item()+"/>
    <xsl:sequence select="map {
      'apply': $apply-fn,
      
      'bind' : function($binder as function(item()*) as map(*)) as map(*) {
        let $bound-apply-fn := function($realworld) {
          let $io-res := $apply-fn($realworld)
          return
            $binder(fn:tail($io-res))('apply')(fn:head($io-res))
        }
        return
          task:create-monadic-task($bound-apply-fn)
      },
      
      'then': function($next as map(*)) as map(*) {
        let $then-apply-fn := function($realworld) {
          let $io-res := $apply-fn($realworld)
          (: NOTE: the result given by fn:head($io-res)
            is not needed by `then`, so we can ignore it :)
          return
            $next('apply')(fn:head($io-res))
        }
        return
          task:create-monadic-task($then-apply-fn)
      },
      
      'fmap': function($mapper as function(item()*) as item()*) as map(*) {
        let $fmap-apply-fn := function($realworld as element(adt:realworld)) as item()+ {
          let $io-res := $apply-fn($realworld)
          return
            (fn:head($io-res), $mapper(fn:tail($io-res)))
        }
        return
          task:create-monadic-task($fmap-apply-fn)
      },
      
      'sequence': function($tasks as map(xs:string, function(*))+) as map(*) {
        let $sequence-apply-fn := function($realworld as element(adt:realworld)) as item() + {
          let $io-res := $apply-fn($realworld)
          return
            task:sequence-recursive-apply(fn:head($io-res), $tasks, [fn:tail($io-res)])
        }
        return
          task:create-monadic-task($sequence-apply-fn)
      },
      
      'async': function() as map(*) {
        let $async-apply-fn := function($realworld as element(adt:realworld)) as item() + {
          let $exec-NO-async := $apply-fn($realworld), 
          $async-a := function($scheduler as element(adt:scheduler)) as item()+ {
            ($scheduler, fn:tail($exec-NO-async))
          }
          return
          (: NOTE - we use $realworld and NOT fn:head($exec-NO-async) as
          the realworld in the return, because our (theoretically) asynchronously
          executing code cannot return a real world to us :)
            ($realworld, $async-a)
        }
        return
          task:create-monadic-task($async-apply-fn)
      },
      
      'RUN-UNSAFE': function() as item()* {
        (: THIS IS THE DEVIL's WORK! :)
        subsequence(
          $apply-fn($realworldEl), 2)
      }
      }"/>
  </xsl:function>
  
  <!-- Creates a Task from a "pure" value.
    @param a pure value
    @return a Task which when executed returns the pure value. -->
  <xsl:function name="task:value" as="map(*)">
    <xsl:param name="u" as="item()*"/>
    <xsl:sequence select="task:create-monadic-task(function($realworld) {
        ($realworld, $u)
      })"/>
  </xsl:function>
  
  <!-- Creates a Task from a function.
    @param a zero arity function
    @return a Task which when executed returns the pure value. -->
  <xsl:function name="task:of" as="map(*)">
    <xsl:param name="f" as="function() as item()*"/>
    <xsl:sequence select="task:create-monadic-task(function($realworld) {
        ($realworld, $f())
      })"/>
  </xsl:function>
  
  <!-- Internal implementation!
    
    Helper function for task:sequence or ?sequence.
    Given a sequence of tasks, each task will be evaluated in order with the real world progressing from one to the
    next.
    
    @param $realworld a representation of the real world
    @param $tasks the tasks to execute sequentially
    @param $results a workspace where results are accumulated through recursion
    
    @return a sequence, the first item is the new real world, the second item is an array with one entry for each task
      result, in the same order as the tasks. -->
  <xsl:function name="task:sequence-recursive-apply" as="item()+">
    <xsl:param name="realworld" as="element(adt:realworld)"/>
    <xsl:param name="tasks" as="map(*)*"/>
    <xsl:param name="results" as="array(*)"/>
    <xsl:sequence select="if (empty($tasks)) then
        ($realworld, $results)
      else
        let $io-res := fn:head($tasks) ?apply($realworld)
        return
          task:sequence-recursive-apply(fn:head($io-res), fn:tail($tasks), array:append($results, fn:tail($io-res)))"/>
  </xsl:function>
  
  <!-- Creates a new Task representating the sequential application of several other tasks.
    
    When the resultant task is executed, each of the provided tasks will be executed sequentially, and the results
    returned as an array.
    
    @param $tasks the tasks to execute sequentially
    @return A new Task representing the sequential execution of the tasks. -->
  <xsl:function name="task:sequence" as="map(*)">
    <xsl:param name="tasks" as="map(*)+"/>
    <xsl:sequence select="task:create-monadic-task(function($realworld) {
        task:sequence-recursive-apply($realworld, $tasks, [])
      })"/>
  </xsl:function>
  
  <!-- Given an Async this function will extract its value and return a Task of the value.
    
    If the Asynchronous computation represented by the Async has not yet completed, then this function will block until
    the Asynchronous computation completes.
    
    @param $async the asynchronous computation
    @return A new Task representing the result of the completed asynchronous computation. -->
  <xsl:function name="task:wait" as="map(*)">
    <xsl:param name="async" as="function(element(adt:scheduler)) as item()+"/>
    <xsl:sequence select="let $wait-apply-fn := function($realworld as element(adt:realworld)) as item()+ {
        let $async-res := $async($schedulerEl)
        return
          ($realworld, fn:tail($async-res))
      }
      return
        task:create-monadic-task($wait-apply-fn)"/>
  </xsl:function>
  
  <!-- Given multiple Asyncs this function will extract their values and return a Task of the values.
    
    If any of the Asynchronous computations represented by the Asyncs have not yet completed, then this function will
    block until all of the Asynchronous computations have completed.
    
    @param $asyncs the asynchronous computations
    @return A new Task representing the result of the completed asynchronous computations. -->
  <xsl:function name="task:wait-all" as="map(*)">
    <xsl:param name="asyncs" as="array(function(element(adt:scheduler)) as item()+)"/>
    <xsl:sequence select="let $wait-all-apply-fn := function($realworld as element(adt:realworld)) as item()+ {
        let $scheduler := $schedulerEl (: all were executed on the same (imaginary) scheduler :),
        $asyncs-res := array:for-each(array:for-each($asyncs, fn:apply(?, [$scheduler])),
          fn:tail#1) (: fn:tail is used to drop the $schedulerEl s :)
        return
          ($realworld, $asyncs-res)
      }
      return
        task:create-monadic-task($wait-all-apply-fn)"/>
  </xsl:function>
  
  <!-- Given an Async this function will attempt to cancel the asynchronous process.
    
    This is a best effort approach. There is no guarantee that the asynchronous process will obey cancellation.
    
    If the Asynchronous computation represented by the Async has already completed, then no cancellation will occur.
    
    @param $async the asynchronous computation
    @return A new Task representing the action to cancel an asynchronous computation. -->
  <xsl:function name="task:cancel" as="map(*)">
    <xsl:param name="async" as="function(element(adt:scheduler)) as item()+"/>
    <xsl:sequence select="let $cancel-apply-fn := function($realworld as element(adt:realworld)) as item()+ {
      (: we can't implement this properly in XPath, as the async will have
      already executed synchronously as our XSLT implementation
      is purely synchronous; so we don't really have to do anything here! :)
        ($realworld, ())
      }
      return
        task:create-monadic-task($cancel-apply-fn)"/>
  </xsl:function>
  
  <!-- Given multiple Asyncs this function will attempt to cancel all of the asynchronous processes.
    
    This is a best effort approach. There is no guarantee that any asynchronous process will obey cancellation.
    
    If any of the the Asynchronous computations represented by the Asyncs have already completed, then those will not be
    cancelled.
    
    @param $asyncs the asynchronous computations
    @return A new Task representing the action to cancel the asynchronous computations. -->
  <xsl:function name="task:cancel-all" as="map(*)">
    <xsl:param name="asyncs" as="array(function(element(adt:scheduler)) as item()+)"/>
    <xsl:sequence select="let $cancel-all-apply-fn := function($realworld as element(adt:realworld)) as item()+ {
      (: we can't implement this properly in XPath, as the async will have
      already executed synchronously as our XSLT implementation
      is purely synchronous; so we don't really have to do anything here! :)
        ($realworld, ())
      }
      return
        task:create-monadic-task($cancel-all-apply-fn)"/>
  </xsl:function>
  
  <!-- Executes a Task.
    
    WARNING 
      - There should only be one of these in your application. It should likely be the last expression in your
      application.
      - This function reveals non-determinism if the actions that it encapsulates are non-deterministic!
      
    @param The task to execute
    @return The result of the task -->
  <xsl:function name="task:RUN-UNSAFE">
    <xsl:param name="task" as="map(*)"/>
    <xsl:sequence select="subsequence(
        $task?apply($realworldEl),
        2
      )"/>
  </xsl:function>
  
  <!-- TODO: Implement error handling with task:error, task:catches, etc. -->

  
</xsl:stylesheet>
