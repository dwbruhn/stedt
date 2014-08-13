-- create denormalized versions of lexicon and etyma tables
-- NOTE: modify FILE-PATH-HERE before running 

-- create temporary table to hold stedt tagging
CREATE TABLE stedt_tags (PRIMARY KEY (rn)) AS
SELECT rn, GROUP_CONCAT(tag_str) AS tagging
FROM lx_et_hash
WHERE uid=8
GROUP BY rn
ORDER BY rn;

-- dump various fields of lexicon table (joined with a few other tables)
SELECT rn AS id, languagenames.language, reflex AS form, gloss, gfn, semkey, tagging AS analysis, CONCAT_WS(' - ',grpno,grp) AS subgroup, srcabbr, citation, srcid
FROM lexicon
LEFT JOIN stedt_tags USING (rn)
LEFT JOIN languagenames USING (lgid)
LEFT JOIN languagegroups USING (grpid)
LEFT JOIN srcbib USING (srcabbr)
WHERE lexicon.status != 'DELETED' AND lexicon.status != 'HIDE'
ORDER BY rn
INTO OUTFILE 'FILE-PATH-HERE';

-- dump various fields of etyma table
SELECT tag, plg, protoform, protogloss,notes,chapter AS semkey
FROM etyma
LEFT JOIN languagegroups USING (grpid)
WHERE STATUS != 'DELETE'
ORDER BY tag
INTO OUTFILE 'FILE-PATH-HERE';