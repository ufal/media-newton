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

  <xsl:template match="Summary[10 > position()]//Article">
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
        <respStmt>
          <persName ref="https://orcid.org/0000-0001-7953-8783">Matyáš Kopp</persName>
          <resp xml:lang="en">TEI XML corpus encoding</resp>
        </respStmt>
      </titleStmt>
      <editionStmt>
        <edition>1.0</edition>
      </editionStmt>
      <sourceDesc>
        <bibl>
          <title type="main" xml:lang="cs"><xsl:value-of select="$title"/></title>
          <author sameAs="#TODO">
            <persName>TODO</persName>
          </author>
          <idno type="URI">TODO</idno>
          <!-- 
          <date when="{$date}">{$date}</date>
          <note type="section"><tag sameAs="#sect-52935">Zprávy z domova</tag></note>
          <note type="tag"/>
          <district type="domicil"></district>
          -->
        </bibl>
      </sourceDesc>
    </fileDesc>
  </teiHeader>
</TEI>

    </xsl:result-document>
  </xsl:template>

</xsl:stylesheet>