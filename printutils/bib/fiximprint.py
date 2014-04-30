#!usr/bin/env python

import sys
import os
import itertools
import re

bib = []
for line in open('stedtreferences.bib','r'):
  bib.append(re.split(r'\s\=',line))

newbib = []

def imprint( bib ):
  journ = re.compile(r'.*\d+\:\d+') #regex to find journal imprint
  book = re.compile(r'\w*\:\ \w*') #regex to find book imprint
  for line in bib:
    if line[0] == 'imprint ':
      if re.match(journ,line[1]):
        parts = re.split(r'[\d]*',line[1][1:-3])
        if '. ' in line[1][1:-3]:
          pgs = line[1][1:-3].split('. ')[-1].split(':')
        else:
          pgs = line[1][1:-3].split()[-1].split(':')
        journl = ['journal',str('{'+parts[0].strip(' .')+'},\n')]
        vol = ['volume',str('{'+pgs[0].strip(' .')+'},\n')]
        pgs = ['pages',str('{'+pgs[1].strip(' .')+'},\n')]
        newbib.append(journl)
        newbib.append(vol)
        newbib.append(pgs)
      if re.match(book,line[1]):
        parts = line[1].split(': ')
        address = ['address',str('{'+parts[0]+'},\n')]
        publisher = ['publisher',str('{'+parts[1]+'},\n')]
        newbib.append(address)
        newbib.append(publisher)
      else:
        newbib.append(line)
    else:
      newbib.append(line)
  return newbib

def main():
  imprint(bib)
  for line in newbib:
    print '\t= '.join(line),

#not ready for primetime yet:
#  f = open('stedtreferences.bib', 'w')
#  for line in newbib:
#    f.write(line)
#    f.close()


if __name__ == "__main__":
  main()
