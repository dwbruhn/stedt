#!usr/bin/env python

import sys
import os
import itertools
import re

sources = [] #empty list which takes source chunks of stedtreferences
f = open('stedtreferences.bib','r')
text = f.read()
f.close()
text = text.replace('\xe2\x80\x93','-')
for line in re.split(r'(@[^@]*)',text)[1::2]: #makes each bib entry into a list item, splitting inclusively by @
  sources.append(line)  #pipes into empty list

bib = [] #empty list to serve as 3-level list: list=>source=>sourcefields
for line in sources:
  row = []
  for subline in line.split('\n'): #split by newline
    subrow = []
    for word in re.split(r'\s\=\s', subline): #split by '  = '
      subrow.append(word) #put each source field element in source field line
    row.append(subrow) #put each source field line in source line
  bib.append(row) #put each source line in bib

for line in bib: 
  for subline in line:
    if len(subline) > 1:
      if subline[1] == '{},':           #get rid of empty fields 
        line.pop(line.index(subline))   #automatically generated by makeBib

journ = re.compile(r'.*[\d|\(|\)]+\:\d+[\-]\d+') #regex to find journal imprint, e.g., '97:123-234'
book = re.compile(r'.*\w*\:\ \w*') #regex to find book imprint, e.g., 'Wiesbaden: Reichert'

#look for journals, edited volumes, series, dissertations,

def imprint( bib ):
  for line in bib:
    for subline in line:
      if subline[0].startswith('imprint'):
        if re.match(journ,subline[1]) and not re.match(book,subline[1]): #journal regex found?
          parts = re.split(r'(\d.*\d)', subline[1]) #split by '124:1324-1234' to separate journal title from volume/pgs
          subparts = re.split(r'\:', parts[1]) #split 2nd element of above list by ':' to separate volume from pgs
          journal = ['journal\t',str(parts[0].strip()+'},')] #remake journal field
          line.insert(-4,journal)
          volume = ['volume\t',str('{'+subparts[0]+'},')] #remake volume field
          line.insert(-4,volume)
          pages = ['pages\t',str('{'+subparts[1]+'},')] #remake pages field
          line.insert(-4,pages)
        if re.match(book,subline[1]): #book regex found?
          if subline[1].startswith('{In: '): #is this an edited volume?
            line[0][0].replace('@book','@incollection')
            parts = re.split(r'\{In\:\ |\(eds*\.\)\,\ |(\:\ [\w\s\.]*},$)|\,\ pp\.\ |(\d+\-\d+)\. |(\(\w+\s.*\))', subline[1]) #get all relevant fields
            newparts = []
            for part in parts:
              draff = r'\.|\:| '
              if part != None and part != '' and part != ' ':
                newparts.append(part.strip(draff))
            if len(newparts) == 3:
              editor = ['editor\t',str('{'+newparts[0]+'},')]
              line.insert(-4,editor)
              booktitle = ['booktitle\t',str('{'+newparts[1]+'},')]
              line.insert(-4,booktitle)
              pages = ['pages\t',str('{'+newparts[2])]
              line.insert(-4,pages)
            if len(newparts) == 4:
              editor = ['editor\t',str('{'+newparts[0]+'},')]
              line.insert(-4,editor)
              booktitle = ['booktitle\t',str('{'+newparts[1]+'},')]
              line.insert(-4,booktitle)
              pages = ['pages\t',str('{'+newparts[2]+'},')]
              line.insert(-4,pages)
              address = ['address\t',str('{'+newparts[3])]
              line.insert(-4,address)
            if len(newparts) == 5:
              editor = ['editor\t',str('{'+newparts[0]+'},')]
              line.insert(-4,editor)
              booktitle = ['booktitle\t',str('{'+newparts[1]+'},')]
              line.insert(-4,booktitle)
              pages = ['pages\t',str('{'+newparts[2]+'},')]
              line.insert(-4,pages)
              address = ['address\t',str('{'+newparts[3]+'},')]
              line.insert(-4,address)
              publisher = ['publisher\t',str('{'+newparts[4])]
              line.insert(-4,publisher)
            if len(newparts) == 6:
              editor = ['editor\t',str('{'+newparts[0]+'},')]
              line.insert(-4,editor)
              booktitle = ['booktitle\t',str('{'+newparts[1]+'},')]
              line.insert(-4,booktitle)
              pages = ['pages\t',str('{'+newparts[2]+'},')]
              line.insert(-4,pages)
              servol = newparts[3][1:-1].split(', ')
              for word in servol:
                if word == 'No.' or word == 'no.' or word == 'Vol.':
                  servol.pop(servol.index(word))
              series = ['series\t',str('{'+' '.join(servol[0:-1])+'},')]
              line.insert(-4,series)
              if servol[-1].startswith('No.') or servol[-1].startswith('no.'):
                number = ['number\t',str('{'+re.split(r'(\d+)', servol[-1])[-1]+'},')]
                line.insert(-4,number)
              else:
                volume = ['volume\t',str('{'+servol[-1]+'},')]
                line.insert(-4,volume)
              address = ['address\t',str('{'+newparts[4]+'},')]
              line.insert(-4,address)
              publisher = ['publisher\t',str('{'+newparts[5])]
              line.insert(-4,publisher)
          else: #book, but not edited volume
            parts = re.split(r'{(\([^\(]*\))|\:\ ', subline[1]) #split by series parenthetical, colon
            newparts = []
            for part in parts:
              draff = r'\.|\:| '
              if part != None and part != '' and part != ' ':
                newparts.append(part.strip(draff))
            if len(newparts) == 3:
              if not newparts[0].startswith('{'): #makes sure actually a series
                servol = newparts[0][1:-1].split()
                for word in servol:
                  if word == 'No.' or word == 'no.' or word == 'Vol.':
                    servol.pop(servol.index(word))
                series = ['series\t',str('{'+' '.join(servol[0:-1]).strip(',')+'},')]
                line.insert(-4,series)
                if servol[-1].startswith('No.') or servol[-1].startswith('no.'):
                  number = ['number\t',str('{'+re.split(r'(\d+)', servol[-1])[-1]+'},')]
                  line.insert(-4,number)
                else:
                  volume = ['volume\t',str('{'+servol[-1]+'},')]
                  line.insert(-4,volume)
                address = ['address\t',str('{'+newparts[1]+'},')]
                line.insert(-4,address)
                publisher = ['publisher\t',str('{'+newparts[2])]
                line.insert(-4,publisher)
              else:
                address = ['address\t',str(newparts[0]+'},')]
                line.insert(-4,address)
                publisher = ['publisher\t',str('{'+' '.join(newparts[1:])+'},')]
                line.insert(-4,publisher)
            if len(newparts) == 2:
              address = ['address\t',str(newparts[0]+'},')]
              line.insert(-4,address)
              publisher = ['publisher\t',str('{'+newparts[1])]
              line.insert(-4,publisher)
        if subline[1].startswith('{Ph.D. Dissertation') or subline[1].startswith('Ph.D Dissertation') or subline[1].startswith('PhD Dissertation') or re.match(r'.*Ph\.*D\.*\sDiss', subline[1]): #dissertation?
          school = ['school\t',str('{'+subline[1].split('{Ph.D. Dissertation, ')[-1])]
          line.insert(-4,school)
          line[0][0] = line[0][0].replace('@book','@phdthesis')
          
#        else:
#	      subline[0] = subline[0].replace('imprint', 'address')

  for line in bib:
    if line[0][0].startswith('@article') or line[0][0].startswith('@phd'):
      for subline in line:
        if subline[0].startswith('address') or subline[0].startswith('imprint'):
          line.pop(line.index(subline))

  for line in bib:
    counter = 0
    for subline in line:
      if subline[0].startswith('address'):
        counter += 1
    if counter == 0:
      for subline in line:
        if subline[0].startswith('imprint'):
          subline[0] = subline[0].replace('imprint', 'note')
        
  for line in bib:
    for subline in line:
      if subline[0].startswith('editor'):
        line[0][0] = line[0][0].replace('@book','@incollection')

  for line in bib:
    if line[0][0].startswith('@article') or line[0][0].startswith('@PhD'):
      for subline in line:
        if subline[0].startswith('address'):
          line.pop(line.index(subline))

  for line in bib:
    if line[0][0].startswith('@book'):
      for subline in line:
        if subline[0].startswith('author'):
          if ', ed.' in subline[1] or ', eds.' in subline[1] or ', (eds.)' in subline[1] or ', (ed.)' in subline[1]:
            line[0][0] = line[0][0].replace('@book','@collection')
            subline[1] = re.sub(', \(*eds*\.\)*', '', subline[1])          



def main():
  imprint(bib)
  f = open('stedtreferences.bib', 'w')
  for line in bib:
    for subline in line:
      f.write('= '.join(subline)+'\n')
  f.close()

if __name__ == "__main__":
  main()
