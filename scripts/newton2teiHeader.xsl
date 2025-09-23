<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  exclude-result-prefixes="xs tei mk" >

  <xsl:output method="xml" indent="yes" encoding="UTF-8" />
  <xsl:import href="newton2tei-lib.xsl"/>

  <xsl:template match="Summary[not($limit) or $limit >= position()]//Article">
    <xsl:variable name="id" select="mk:id(.)"/>
    <xsl:variable name="path" select="mk:path(., $outDir)"/>
    <xsl:message select="concat('INFO: exporting ',$path)"/>
    <xsl:variable name="title" select="mk:title(.)"/>

    <xsl:result-document href="{$path}" method="xml" indent="yes" encoding="UTF-8" >

<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}" xml:lang="cs">
  <teiHeader>
    <fileDesc>
      <titleStmt>
        <title type="main"><xsl:value-of select="$title"/></title>
      </titleStmt>
      <sourceDesc>
        <bibl>
          <title type="main" xml:lang="cs"><xsl:value-of select="$title"/></title>
        </bibl>
      </sourceDesc>
    </fileDesc>
  </teiHeader>
</TEI>

    </xsl:result-document>
  </xsl:template>

</xsl:stylesheet>