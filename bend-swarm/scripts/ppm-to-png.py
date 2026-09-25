#!/usr/bin/env python3
"""Lossless export of a native Bend P3 framebuffer, with no image dependencies."""
import pathlib,struct,sys,zlib

def convert(source,target):
    tokens=pathlib.Path(source).read_text().split()
    if tokens[0]!='P3' or tokens[3]!='255': raise ValueError('expected 8-bit P3 PPM')
    width,height=map(int,tokens[1:3]);data=bytes(map(int,tokens[4:]))
    if len(data)!=width*height*3: raise ValueError('incomplete framebuffer')
    rows=b''.join(b'\0'+data[y*width*3:(y+1)*width*3] for y in range(height))
    def chunk(kind,body):
        return struct.pack('!I',len(body))+kind+body+struct.pack('!I',zlib.crc32(kind+body))
    pathlib.Path(target).write_bytes(b'\x89PNG\r\n\x1a\n'+
        chunk(b'IHDR',struct.pack('!2I5B',width,height,8,2,0,0,0))+
        chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b''))

if __name__=='__main__': convert(*sys.argv[1:])
