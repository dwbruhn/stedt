
  CREATE INDEX idx_morphemes_rn ON morphemes (rn);
  CREATE INDEX idx_morphemes_lgid ON morphemes (lgid);
  CREATE INDEX idx_morphemes_mseq ON morphemes (mseq);
  CREATE INDEX idx_morphemes_morpheme ON morphemes (morpheme);
  CREATE INDEX idx_morphemes_handle ON morphemes (handle);

  CREATE INDEX idx_morphemes_prefx ON morphemes (prefx);
  CREATE INDEX idx_morphemes_initial ON morphemes (initial);
  CREATE INDEX idx_morphemes_rhyme ON morphemes (rhyme);
  CREATE INDEX idx_morphemes_tone ON morphemes (tone);

  CREATE INDEX idx_morphemes_grp ON morphemes (grp);
  CREATE INDEX idx_morphemes_grpno ON morphemes (grpno);
  CREATE INDEX idx_morphemes_language ON morphemes (language);
  CREATE INDEX idx_morphemes_semkey ON morphemes (semkey);
  CREATE INDEX idx_morphemes_reflex ON morphemes (reflex);
  CREATE INDEX idx_morphemes_gloss ON morphemes (gloss);
  CREATE INDEX idx_morphemes_gfn ON morphemes (gfn);
  CREATE index idx_morphemes_tag on stedt.morphemes (tag);
