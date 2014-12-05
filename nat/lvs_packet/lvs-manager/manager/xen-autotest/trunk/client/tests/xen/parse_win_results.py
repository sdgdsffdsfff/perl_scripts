#!/usr/bin/python
"""
Program that parses the win performance test output and  return a dict of keylists to be logged as keyval.

"""
import os, re, string
#from autotest_lib.client.bin import test, utils


def parse_results(raw_result,result_parser):
    """
    Parse text containing win performance test  results.

    @param raw_result: plain text input for result
    @param result_parser: process function for the specific test
    @return: A list of keyval.
    """

    def iozone_parser(text):
        """
        Parse iozone result to keyval

        @return: A list of keyval.
        """
        keylist = {}
        labels = ('write', 'rewrite', 'read', 'reread', 'randread',
                  'randwrite', 'bkwdread', 'recordrewrite',
                  'strideread', 'fwrite', 'frewrite', 'fread', 'freread')
        for line in text.splitlines():
            fields = line.split()
            if len(fields) != 15:
                continue
            try:
                fields = tuple([int(i) for i in fields])
            except ValueError:
                continue
            for l, v in zip(labels, fields[2:]):
                key_name = "%d-%d-%s" % (fields[0], fields[1], l)
                keylist[key_name] = v
        return keylist

    def super_pi_parser(text):
        """
        Parse super_pi result to keyval
        Note:
        pi_size is "1M" for now,if change this, also needs to 
        change the au3 scripts in windows

        @return: A list of keyval.Will retrun {} if no value calculated
        """
        pi_size="1M"
        keylist={}
        lines=text.splitlines()
        for line in lines:
            if line.find(pi_size) != -1:
                if line.startswith("+"):
                    values=line.split()
                    pi_hour=values[1].strip('h')
                    pi_min=values[2].strip('m')
                    pi_sec=values[3].strip('s')
                    total_sec=int(pi_hour)*3600+int(pi_min)*60+int(pi_sec)
                else:
                    print "not calculated for this value"
                    total_sec= -1
                    break
        if total_sec >0:
            key_name="PI_"+pi_size+"_Seconds"
            keylist[key_name]=total_sec
        return keylist

    def linpack_parser(text):
        """
        Parse linpack result to keyval
        Note: the LinX program return a result file with '0x00' so
              we have to get rid of them during parsing.

        @return: A list of keyval.
        """
        keylist={}
        text2=[]

        for i in text:
            i = filter(lambda x : x in string.printable, i)
            text2.append(i)
        text3=''.join(text2)
        lines=text3.splitlines()

        for line in lines:
            if line.startswith("Performance"):
                values=lines[lines.index(line)+3]
                value=values.split()
                try:
                    value = tuple([float(f) for f in value])
                except ValueError:
                    print "value error"
                break
        keyname= "size-%d-GFlops" % int(value[0])
        keylist[keyname]=value[4]
        return keylist

    win_parser= {'iozone':iozone_parser,
                    'super_pi':super_pi_parser,
                    'linpack':linpack_parser}

    try:
        result=win_parser[result_parser](raw_result)
    except KeyError:
        print "bad result_parser!"
        result=None

    return result


if __name__ == '__main__':
    import sys, os, glob
    if len(sys.argv) > 1:
        if sys.argv[1] == '-h' or sys.argv[1] == '--help':
            print 'Usage: %s <result_file> <result_parser>' % sys.argv[0]
            sys.exit(0)
        resfile = sys.argv[1]
        result_parser=sys.argv[2]

        try:
            f = file(resfile)
            text = f.read()
            f.close()
        except IOError:
            print 'Bad result file: %s' % resfile
        keyval=parse_results(text,result_parser)
        print keyval
