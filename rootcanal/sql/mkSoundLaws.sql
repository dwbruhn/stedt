DROP TABLE IF EXISTS sl;
CREATE TABLE sl 
SELECT 
x.rn AS rn,
x.tag AS tag,
m.mseq AS mseq,
x.ind AS ind,
'I' AS slot,
e.plg AS protolg,
e.initial AS ancestor,
m.initial AS outcome,
m.language AS language,
m.lgid AS lgid,
m.srcabbr AS srcabbr,
m.srcid AS srcid,
e.protoform AS protoform,
m.morpheme AS reflex
FROM lx_et_hash x JOIN morphemes m on (x.rn=m.rn) JOIN etyma e WHERE e.tag = x.tag and m.mseq=x.ind
;

INSERT INTO sl 
SELECT 
x.rn AS rn,
x.tag AS tag,
x.ind AS ind,
m.mseq AS mseq,
'R' AS slot,
e.plg AS protolg,
e.rhyme AS ancestor,
m.rhyme AS outcome,
m.language AS language,
m.lgid AS lgid,
m.srcabbr AS srcabbr,
m.srcid AS srcid,
e.protoform AS protoform,
m.morpheme AS reflex
FROM lx_et_hash x JOIN morphemes m on (x.rn=m.rn) JOIN etyma e WHERE e.tag = x.tag and m.mseq=x.ind
;

update sl set ancestor = left(ancestor,instr(ancestor,'⪤')-1) WHERE instr(ancestor,'⪤') > 0;
update sl set ancestor = left(ancestor,instr(ancestor,' ')-1) WHERE instr(ancestor,' ') > 0;
update sl set ancestor = left(ancestor,instr(ancestor,'=')-1) WHERE instr(ancestor,'=') > 0;
update sl set ancestor = left(ancestor,instr(ancestor,'~')-1) WHERE instr(ancestor,'~') > 0;
update sl set outcome = ltrim(outcome), ancestor=ltrim(ancestor);
update sl set outcome = rtrim(outcome), ancestor=rtrim(ancestor);

DROP TABLE IF EXISTS soundlaws;
CREATE TABLE soundlaws SELECT rn,tag AS corrid, slot,protolg,ancestor,outcome,language,'' AS context,count(*) AS n,srcabbr,srcid,lgid FROM sl  group by slot,ancestor,outcome,language ORDER BY n;
ALTER TABLE soundlaws ADD id INT NOT NULL AUTO_INCREMENT FIRST, ADD PRIMARY KEY (id);
DELETE FROM soundlaws WHERE n < 2;
DELETE FROM soundlaws WHERE outcome = '' OR ancestor = '';

DROP TABLE sl;