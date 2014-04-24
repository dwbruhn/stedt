#!/usr/bin/env python

import sys
import os
import csv

cites = []
for row in csv.reader(open('cites.csv', 'r')):
  for word in row:
    cites.append(str('\\citealt{'+ word +'}'))

def main():
  f = open('sources.tex', 'w')
  for word in cites:
    f.write(word+'\n')
  f.close()

if __name__ == "__main__":
  main()


