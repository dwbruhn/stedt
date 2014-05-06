#!usr/bin/env python

import sys
import os
import itertools
import re

sources = []
f = open('stedtreferences.bib','r')
text = f.read()
f.close()
for line in re.split(r'(@[^@]*)',text)[1::2]: #makes each bib entry into a list item
  sources.append(line)

bib = []
for line in sources:
  row = []
  for subline in line.split('\n'):
    subrow = []
    for word in re.split(r'\s\=\s', subline):
      subrow.append(word)
    row.append(subrow)
  bib.append(row)

for line in bib:
  for subline in line:
    if len(subline) > 1:
      if subline[1] == '{},':
        line.pop(line.index(subline))

newbib = []

def imprint( bib ):
  journ = re.compile(r'.*\d+\:\d+') #regex to find journal imprint
  book = re.compile(r'\w*\:\ \w*') #regex to find book imprint
  for line in bib:
    for subline in line:
      if subline[0] == 'imprint ':
        if re.match(journ,subline[1]):
          parts = re.split(r'[\d]*',subline[1][1:-3])
          if '. ' in subline[1][1:-3]:
            pgs = subline[1][1:-3].split('. ')[-1].split(':')
          else:
            pgs = subline[1][1:-3].split()[-1].split(':')
          journl = ['journal',str('{'+parts[0].strip(' .')+'},')]
          vol = ['volume',str('{'+pgs[0].strip(' .')+'},')]
          if len(pgs) > 1:
            pgs = ['pages',str('{'+pgs[1].strip(' .')+'},')]
          line.insert(-4,journl)
          line.insert(-4,vol)
          line.insert(-4,pgs)
        if re.match(book,subline[1]):
          parts = subline[1].split(': ')
          address = ['address',str('{'+parts[0]+'},')]
          publisher = ['publisher',str('{'+parts[1]+'},')]
          line.insert(-4,address)
          line.insert(-4,publisher)
  return bib
#        else:
#          newbib.append(subline)
#      else:
#        newbib.append(subline)
#  return newbib

def main():
#  imprint(bib)
#  for line in bib:
#    for subline in line:
#      print '\t\t= '.join(subline)
#not ready for primetime yet:
  imprint(bib)
  f = open('stedtreferences.bib', 'w')
  for line in bib:
    for subline in line:
      f.write('\t\t= '.join(subline)+'\n')
  f.close()


if __name__ == "__main__":
  main()
