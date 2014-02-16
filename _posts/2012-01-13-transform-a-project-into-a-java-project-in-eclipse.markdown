---
author: Michael Paquier
comments: true
lastmod: 2012-01-13
date: 2012-01-13 13:58:39+00:00
layout: post
type: post
slug: transform-a-project-into-a-java-project-in-eclipse
title: Transform a project into a java project in eclipse
wordpress_id: 715
categories:
- Java
tags:
- beginner
- developer
- eclipse
- fetch
- folder
- git
- java
- programmer
- project
- source
---

This article is made using Eclipse 3.7 and its famous plug-in dedicated to GIT called [Egit](http://eclipse.org/egit/
).

When working on a java project, eclipse is a nice way to implement, code and debug. It is even nicer when it can be used with a version controller like GIT. Since Eclipse 3.5, GIT has its own plug-in called EGit. Let's be honest. It rocks. The interface is well-thought, and you can manage easily your GIT repository through friendly interface. In case you get crazy with some error messages, you can still easily fallback to the good-old command terminal, and everything made will still be visible in Eclipse. That is really a nice tool

However, when starting a new Java project from an existing GIT repository, you can easily import your project by doing Files -> Import. Then in the import window, select Git -> Projects from GIT.
And in a couple of clicks, you are able to clone existing repositories, and add new projects. The problem is that you generally need to import the code as a general project, and under Eclipse it will be recognized as a Java project.

There is a workaround for this problem after importing a GIT code as a general project. You first need to modify the .project file in the project repository and modify it as below to make it a Java project.

    <projectDescription>
      <name>my_project</name>
      <comment></comment>
      <projects>
      </projects>
      <buildSpec>
        <buildCommand>
          <name>org.eclipse.jdt.core.javabuilder</name>
          <arguments>
          </arguments>
        </buildCommand>
      </buildSpec>
      <natures>
        <nature>org.eclipse.jdt.core.javanature</nature>
      </natures>
    </projectDescription>

Then, restart eclipse. So now the project became a Java project, but there are still no JRE libraries.
In order to do that, modify .classpath as follows:

    <classpath>
      <classpathentry kind="con" path="org.eclipse.jdt.launching.JRE_CONTAINER"/>
    </classpath>

What remains to do, depending on the project is to add at least a source folder. This can be done by right-clicking on the project, then New -> Source Folder.
And you are done.
