<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <html>
      <head>
	<title>Etymology</title>
	<style type="text/css">
	  table { 
	    padding-left: 18pt;
	    width: 90%; }

	  html { 
	    font-family: STEDTU,"TITUS Cyberbit Basic",
	      SILDoulosUnicodeIPA,Gentium,Thryomanes,Cardo,
              "Arial Unicode MS","Lucida Sans Unicode";
	    font-size: 12pt; }

	  hr { 
	    width: 100%;
	    text-align: left; }

	  th {
	    text-align: left;
	    color: white;
	    background-color: DarkBlue;
	    font-family: Arial, Helvetica, sans;
	    font-weight: normal; }

	  h1 {
	    font-family: Arial, Helvetica, sans;
	    font-size: 24pt;
	    font-weight: bold; }

	  h2 {
	    text-align: center;
	    font-size: 18pt;
	    font-weight: bold;
	    margin-left: 12pt;
	    }

	  h3 {
	    font-family: Arial, Helvetica, sans;
	    font-size: 16pt;
	    font-weight: bold;
	    margin-left: 16pt; }

	  h4 {
	    font-family: Arial, Helvetica, sans;
	    font-size: 14pt;
	    font-weight: normal;
	    margin-left: 18pt; }

	  span.stedtnum {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 2em 0em 0em;
	    width: 33%; }

	  span.paf {
	    padding: 0em 2em 0em 0em;
	    /* font-style: italic; */
	    width: 33%; }

	  span.pgloss {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 0em 0em 0em;
	    width: 33%; }

	  span.cognate {
            font-weight: bold; }

	  .lgname {
	    width: 25% }

	  .rn {
	    width: 5% }

	  .analysis {
	    width: 10% }

	  .form {
	    width: 20% }

	  .gloss {
	    width: 20% }

	  .srcabbr {
	    width: 10% }

	  .srcid {
	    width: 10% }

	  div.note {
	    padding-left: 18pt;
	    text-align: justify;
	    width: 90%;
	    }

	  .xref {
	  font-family: Arial, Helvetica, sans;
	  }

	  .reconstruction, .latinform {
	  font-weight: bold;
	  text-decoration: underline;
	  }

	</style>
      </head>
      <body>
	<xsl:for-each select="fascicle">
	  <xsl:for-each select="chapter">
	    <h1>
	      <span class="chapternum">
		<xsl:value-of select="chapternum"/>. 
	      </span>
	      <span class="chaptertitle">
		<xsl:value-of select="chaptertitle"/>
	      </span>
	    </h1>
	    <xsl:for-each select="etymology">
	      <h2>
		<span class="stedtnum">(<xsl:value-of select="stedtnum"/>)</span>
		<xsl:variable name="tagnum" select="stedtnum"/>
		<span class="paf"><xsl:value-of select="paf"/> </span>
		<span class="pgloss"><xsl:value-of select="pgloss"/> </span>
	      </h2>

	      <h3>Description</h3>

	      <xsl:for-each select="desc">
		<xsl:for-each select="note">
		  <div class="note">
		    <xsl:for-each select="par">
		      <p>
			<xsl:apply-templates />
		      </p>
		    </xsl:for-each>
		  </div>
		</xsl:for-each>
	      </xsl:for-each>

	      <h3>Reflexes</h3>

	      <xsl:for-each select="subgroup">
		<h4>
		  <span class="sgnum"><xsl:value-of select="sgnum"/></span>. 
		  <span class="sgname"><xsl:value-of select="sgname"/></span>
		</h4>
		<table>
		    <tr>
		      <th>Language</th>
		      <th>Rn</th>
		      <th>Analysis</th>
		      <th>Reflex</th>
		      <th>Gloss</th>
		      <th>Src Abbr</th>
		      <th>Src Id</th>
		    </tr>
		  <xsl:for-each select="reflex">
		    <tr>
		      <td class="lgname"><xsl:value-of select="lgname"/></td>
		      <td class="rn"><xsl:value-of select="rn"/></td>
		      <td class="analysis"><xsl:value-of select="analysis"/></td>
		      <td class="form">
                        <xsl:for-each select="form">
                          <xsl:apply-templates />
                        </xsl:for-each>
		      </td>
		      <td class="gloss"><xsl:value-of select="gloss"/></td>
		      <td class="srcabbr"><xsl:value-of select="srcabbr"/></td>
		      <td class="srcid"><xsl:value-of select="srcid"/></td>
		    </tr>
		  </xsl:for-each>
		</table>
	      </xsl:for-each>
	
	    </xsl:for-each>
	  </xsl:for-each>
	</xsl:for-each>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="hanform">
    <span class="hanform">
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

  <xsl:template match="latinform">
    <span class="latinform">
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

  <xsl:template match="reconstruction">
    <span class="reconstruction">
      <xsl:value-of select="."/>
    </span>
  </xsl:template>


  <xsl:attribute-set name="reference">
    <xsl:attribute name="href">
      <xsl:text>etymology.pl?tag=</xsl:text>
      <xsl:value-of select="@ref"/>
    </xsl:attribute>
    <xsl:attribute name="class">
      xref
    </xsl:attribute>
  </xsl:attribute-set>

  <xsl:template match="xref">
    <xsl:element name="a" use-attribute-sets="reference">
      <xsl:value-of select="."/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
