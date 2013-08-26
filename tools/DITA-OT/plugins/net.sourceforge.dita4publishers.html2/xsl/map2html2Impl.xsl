<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xmlns:df="http://dita2indesign.org/dita/functions"  
  xmlns:index-terms="http://dita4publishers.org/index-terms"
  xmlns:relpath="http://dita2indesign/functions/relpath"
  exclude-result-prefixes="xs xd df relpath"
  version="2.0">
  
  <!-- =============================================================
    
       DITA Map to HTML Transformation
       
       Copyright (c) 2010, 2011 DITA For Publishers
       
       Licensed under Common Public License v1.0 or the Apache Software Foundation License v2.0.
       The intent of this license is for this material to be licensed in a way that is
       consistent with and compatible with the license of the DITA Open Toolkit.
       
       This transform requires XSLT 2.
       
       This transform is the root transform and manages the generation
       of the following distinct artifacts:
       
       1. toc.html, which defines the navigation table of contents for the ePub.
       2. The HTML content, generated from the map and topics referenced by the input map.
       3. An input-file-to-output-file map document that is used to copy referenced non-XML
          objects to the appropriate output location.
       
       On request:
       
       4. A JavaScript dynamic ToC
       5. A frameset that includes the ToC and the appropriate HTML page.
       
       This process flattens the resulting HTML such that file system organization of the 
       input map does not matter as far as the HTML organization is concerned.
       
       The input to this transform is a fully-resolved map. All processing of maps
       and topics is driven by references from the map.
       
       ============================================================== -->

  <xsl:import href="../../net.sourceforge.dita4publishers.common.xslt/xsl/lib/dita-support-lib.xsl"/>
  <xsl:import href="../../net.sourceforge.dita4publishers.common.xslt/xsl/lib/relpath_util.xsl"/>
  <xsl:import href="../../net.sourceforge.dita4publishers.common.xslt/xsl/lib/html-generation-utils.xsl"/>
  
  <!-- Import the base HTML output generation transform. -->
  <xsl:import href="../../../xsl/dita2xhtml.xsl"/>
  
  <xsl:import href="../../net.sourceforge.dita4publishers.common.xslt/xsl/graphicMap2AntCopyScript.xsl"/>
  <xsl:import href="../../net.sourceforge.dita4publishers.common.xslt/xsl/map2graphicMap.xsl"/>
  <xsl:import href="../../net.sourceforge.dita4publishers.common.xslt/xsl/topicHrefFixup.xsl"/>
  
  <xsl:include href="../../net.sourceforge.dita4publishers.common.html/xsl/commonHtmlOverrides.xsl"/>
  <xsl:include href="map2html2Content.xsl"/>
  <xsl:include href="map2html2RootPages.xsl"/>
  <xsl:include href="map2html2DynamicToc.xsl"/>
  <xsl:include href="map2html2StaticToc.xsl"/>
  <xsl:include href="map2html2Frameset.xsl"/>
  <xsl:include href="map2html2Index.xsl"/>

  <xsl:include href="map2html2D4P.xsl"/>
  <xsl:include href="map2html2Bookmap.xsl"/>
  
  <xsl:param name="inputFileNameParam"/>
  
  <!-- Directory into which the generated output is put.

       -->
  <xsl:param name="outdir" select="./html2"/>
  <xsl:param name="outext" select="'.html'"/>
  <xsl:param name="tempdir" select="./temp"/>
  
 <!-- The path of the directory, relative the $outdir parameter,
    to hold the graphics in the result HTML package. Should not have
    a leading "/". 
  -->  
  <xsl:param name="imagesOutputDir" select="'images'" as="xs:string"/>
  <!-- The path of the directory, relative the $outdir parameter,
    to hold the topics in the HTML package. Should not have
    a leading "/". 
  -->  
  <xsl:param name="topicsOutputDir" select="'topics'" as="xs:string"/>

  <!-- The path of the directory, relative the $outdir parameter,
    to hold the CSS files in the HTML package. Should not have
    a leading "/". 
  -->  
  <xsl:param name="cssOutputDir" select="'css'" as="xs:string"/>
  
  <xsl:param name="debug" select="'false'" as="xs:string"/>
  
  <xsl:param name="rawPlatformString" select="'unknown'" as="xs:string"/><!-- As provided by Ant -->
  
  <xsl:param name="titleOnlyTopicClassSpec" select="'- topic/topic '" as="xs:string"/>

  <xsl:param name="titleOnlyTopicTitleClassSpec" select="'- topic/title '" as="xs:string"/>
  
  <!-- The strategy to use when constructing output files. Default is "as-authored", meaning
       reflect the directory structure of the topics as authored relative to the root map,
       possibly as reworked by earlier Toolkit steps.
    -->       
  <xsl:param name="fileOrganizationStrategy" as="xs:string" select="'as-authored'"/>
  
  
  <!-- Maxminum depth of the generated ToC -->
  <xsl:param name="maxTocDepth" as="xs:string" select="'5'"/>
  
  <!-- Include back-of-the-book-index if any index entries in source 
  
       For now default to no since index generation is still under development.
  -->  
  <xsl:param name="generateIndex" as="xs:string" select="'no'"/>
  <xsl:variable name="generateIndexBoolean" 
    select="
    lower-case($generateIndex) = 'yes' or 
    lower-case($generateIndex) = 'true' or
    lower-case($generateIndex) = 'on'
    "/>
  
  
  <!-- value for @class on <body> of the generated static TOC HTML document -->
  <xsl:param name="staticTocBodyOutputclass" select="''" as="xs:string"/>
  
  <xsl:param name="contenttarget" select="'contentwin'"/>
  
  <xsl:param name="generateDynamicToc" select="'true'"/>
  <xsl:param name="generateDynamicTocBoolean" select="matches($generateDynamicToc, 'yes|true|or', 'i')"/>
  
  <xsl:param name="generateFrameset" select="'true'"/>
  <xsl:param name="generateFramesetBoolean" select="matches($generateFrameset, 'yes|true|or', 'i')"/>
  
  <xsl:param name="generateStaticToc" select="'false'"/>
  <xsl:param name="generateStaticTocBoolean" select="matches($generateDynamicToc, 'yes|true|or', 'i')"/>
  
  <xsl:template name="report-parameters">
    <xsl:param name="effectiveCoverGraphicUri" select="''" as="xs:string" tunnel="yes"/>
    <xsl:message> 
      ==========================================
      Plugin version: 0.9.18 - build 953 at 2012-01-08
      
      HTML2 Parameters:
      
      + cssOutputDir       = "<xsl:sequence select="$cssOutputDir"/>"
      + fileOrganizationStrategy = "<xsl:sequence select="$fileOrganizationStrategy"/>"  
      + generateDynamicToc = "<xsl:sequence select="$generateDynamicToc"/>"
      + generateFrameset   = "<xsl:sequence select="$generateFrameset"/>"
      + generateIndex      = "<xsl:sequence select="$generateIndex"/>
      + generateStaticToc  = "<xsl:sequence select="$generateStaticToc"/>"
      + imagesOutputDir    = "<xsl:sequence select="$imagesOutputDir"/>"
      + inputFileNameParam = "<xsl:sequence select="$inputFileNameParam"/>"
      + outdir             = "<xsl:sequence select="$outdir"/>"
      + outext             = "<xsl:sequence select="$outext"/>"
      + tempdir            = "<xsl:sequence select="$tempdir"/>"
      + titleOnlyTopicClassSpec = "<xsl:sequence select="$titleOnlyTopicClassSpec"/>"
      + titleOnlyTopicTitleClassSpec = "<xsl:sequence select="$titleOnlyTopicTitleClassSpec"/>"
      + topicsOutputDir    = "<xsl:sequence select="$topicsOutputDir"/>"

      DITA2HTML parameters:
      
      + CSS             = "<xsl:sequence select="$CSS"/>"
      + CSSPATH         = "<xsl:sequence select="$CSSPATH"/>"
      + DITAEXT         = "<xsl:sequence select="$DITAEXT"/>"
      + FILEDIR         = "<xsl:sequence select="$FILEDIR"/>"
      + KEYREF-FILE     = "<xsl:sequence select="$KEYREF-FILE"/>"
      + OUTPUTDIR       = "<xsl:sequence select="$OUTPUTDIR"/>"
      + PATH2PROJ       = "<xsl:sequence select="$PATH2PROJ"/>"
      + WORKDIR         = "<xsl:sequence select="$WORKDIR"/>"
      
      + debug           = "<xsl:sequence select="$debug"/>"

      Global Variables:
      
      + cssOutputPath    = "<xsl:sequence select="$cssOutputPath"/>"
      + topicsOutputPath = "<xsl:sequence select="$topicsOutputPath"/>"
      + imagesOutputPath = "<xsl:sequence select="$imagesOutputPath"/>"
      + platform         = "<xsl:sequence select="$platform"/>"
      + debugBoolean     = "<xsl:sequence select="$debugBoolean"/>"
      
      ==========================================
    </xsl:message>
  </xsl:template>
  
  
  <xsl:output method="xml" name="indented-xml"
    indent="yes"
  />
  
  <xsl:variable name="maxTocDepthInt" select="xs:integer($maxTocDepth)" as="xs:integer"/>
  
  
  <xsl:variable name="platform" as="xs:string"
    select="
    if (starts-with($rawPlatformString, 'Win') or 
        starts-with($rawPlatformString, 'Win'))
       then 'windows'
       else 'nx'
    "
  />
  
  <xsl:variable name="debugBinary" select="$debug = 'true'" as="xs:boolean"/>
  
  <xsl:variable name="topicsOutputPath">
      <xsl:choose>
        <xsl:when test="$topicsOutputDir != ''">
          <xsl:sequence select="concat($outdir, $topicsOutputDir)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="$outdir"/>
        </xsl:otherwise>
      </xsl:choose>    
  </xsl:variable>

  <xsl:variable name="imagesOutputPath">
      <xsl:choose>
        <xsl:when test="$imagesOutputDir != ''">
          <xsl:sequence select="concat($outdir, 
            if (ends-with($outdir, '/')) then '' else '/', 
            $imagesOutputDir)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="$outdir"/>
        </xsl:otherwise>
      </xsl:choose>    
  </xsl:variable>  
  
  <xsl:variable name="cssOutputPath">
      <xsl:choose>
        <xsl:when test="$cssOutputDir != ''">
          <xsl:sequence select="concat($outdir, $cssOutputDir)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="$outdir"/>
        </xsl:otherwise>
      </xsl:choose>    
  </xsl:variable>  
  
  <xsl:template match="/">
    <xsl:apply-templates>
      <xsl:with-param name="rootMapDocUrl" select="document-uri(.)" as="xs:string" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="/*[df:class(., 'map/map')]">
    
    <xsl:call-template name="report-parameters"/>

    <xsl:variable name="uniqueTopicRefs" as="element()*" select="df:getUniqueTopicrefs(.)"/>

    <xsl:variable name="graphicMap" as="element()">
      <xsl:apply-templates select="." mode="generate-graphic-map">
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:result-document href="{relpath:newFile($outdir, 'graphicMap.xml')}" format="graphic-map">
      <xsl:sequence select="$graphicMap"/>
    </xsl:result-document>    
    
    <xsl:message> + [INFO] Gathering index terms...</xsl:message>
    
    <!-- Gather all the index entries from the map and topic. 
    -->
    <xsl:variable name="index-terms" as="element()">
      <index-terms xmlns="http://dita4publishers.org/index-terms">
        <xsl:if test="$generateIndexBoolean">
          <xsl:apply-templates mode="gather-index-terms"/>
        </xsl:if>
      </index-terms>
    </xsl:variable>
    
    <xsl:if test="true() and $debugBoolean">
      <xsl:result-document href="{relpath:newFile($outdir, 'index-terms.xml')}"
        format="indented-xml"
        >
        <xsl:sequence select="$index-terms"/>
      </xsl:result-document>
    </xsl:if>
    
    <!-- NOTE: By default, this mode puts it output in the main output file
         produced by the transform.
      -->
    <xsl:apply-templates select="." mode="generate-root-pages">
      <xsl:with-param name="uniqueTopicRefs" as="element()*" select="$uniqueTopicRefs" tunnel="yes"/>
      <xsl:with-param name="index-terms" as="element()" select="$index-terms" tunnel="yes"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="." mode="generate-content">
      <xsl:with-param name="uniqueTopicRefs" as="element()*" select="$uniqueTopicRefs" tunnel="yes"/>      
    </xsl:apply-templates>
    <xsl:apply-templates select="." mode="generate-index">
      <xsl:with-param name="index-terms" as="element()" select="$index-terms"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="." mode="generate-graphic-copy-ant-script">
      <xsl:with-param name="graphicMap" as="element()" tunnel="yes" select="$graphicMap"/>
    </xsl:apply-templates>
  </xsl:template>
   
</xsl:stylesheet>