<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  exclude-result-prefixes="xs tei mk" >

  <xsl:param name="prefix"/>
  <xsl:param name="outDir"/>
  <xsl:param name="limit"/>
  <xsl:output method="xml" indent="yes" encoding="UTF-8" />

  <xsl:function name="mk:sourceId" as="xs:string">
    <xsl:param name="elem" as="element(Article)"/>
    <xsl:sequence select="$elem/@Id"/>
  </xsl:function>

  <xsl:function name="mk:id" as="xs:string">
    <xsl:param name="elem" as="element(Article)"/>
    <xsl:sequence select="concat($prefix,translate(mk:date($elem),':','-'),'_',mk:sourceId($elem))"/>
  </xsl:function>

  <xsl:function name="mk:date" as="xs:string">
    <xsl:param name="elem" as="element(Article)"/>
    <xsl:sequence select="normalize-space($elem/PublishDate)"/>
  </xsl:function>

  <xsl:function name="mk:yearmonth" as="xs:string">
    <xsl:param name="elem" as="element(Article)"/>
    <xsl:sequence select="substring(string(mk:date($elem)),1,7)"/>
  </xsl:function>
  
  <xsl:function name="mk:article">
    <xsl:param name="elem" as="element(Article)"/>
    <xsl:sequence select="$elem/Translations/ArticleTranslation[@IsOriginal='true']"/>
  </xsl:function>

  <xsl:function name="mk:title" as="xs:string">
    <xsl:param name="elem" as="element(Article)"/>
    <xsl:sequence select="normalize-space(mk:article($elem)/Headline)"/>
  </xsl:function>

  <xsl:function name="mk:path" as="xs:string">
    <xsl:param name="elem" as="element(Article)"/>
    <xsl:param name="dir"/>
    <xsl:sequence select="concat($dir,'/',mk:yearmonth($elem),'/',mk:id($elem),'.xml')" />
  </xsl:function>


  <xsl:function name="mk:number">
    <xsl:param name="num"/>
    <xsl:value-of select="format-number($num,'#0')"/>
  </xsl:function>
</xsl:stylesheet>