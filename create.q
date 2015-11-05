#!/usr/bin/env qore
%new-style

%requires xml
%exec-class Main


const QCOLLECTIONGENERATOR = (
        "qcollectiongenerator",
        "qcollectiongenerator-qt5",
        "qcollectiongenerator.exe",
    );

const QHELPGENERATOR = (
        "qhelpgenerator",
        "qhelpgenerator-qt5",
        "qhelpgenerator.exe",
    );

const OPTS = (
        "outdir" : "o,outdir=s",
        "qcollg" : "c,cgenerator=s",
        "qhelpg" : "g,hgenerator=s",
    );


our hash opts;


sub help(*int exitCode) {
    printf("Usage:
%s <options> srcdir [srcdir...]

Options:
    -o --outdir=ARG      output directory
    -c --cgenerator=ARG  user specified qcollectiongenerator
    -g --hgenerator=ARG  user specified 

", get_script_name());

    if (exists exitCode)
        exit(exitCode);
}

sub realpath(string d) {
    string cmd = sprintf("realpath \"%s\"", d);
    int rc;
    string ret = backquote(cmd, \rc);
    if (rc) {
        printf("realpath failed for: %s\n", d);
        exit(1);
    }
    return trim(ret);
}


class Main {
    constructor() {
        GetOpt go(OPTS);
        opts = go.parse2(ARGV);

        if (!opts.outdir) {
            opts.outdir = get_script_dir();
            printf("Using default outdir: %s\n", opts.outdir);
        }

        opts.outdir = realpath(opts.outdir);

        guessQhelpGenerator();
        guessQCollGenerator();

        if (!ARGV || !ARGV.size()) {
            printf("No source directories given\n");
            help(1);
        }

        list projects = getProjectFiles(ARGV);

        QHelpCollectionProject p(projects);
    }

    private guessQhelpGenerator() {
        opts.qhelpg = guessBinary("qhelpgenerator", QHELPGENERATOR, opts.qhelpg);
    }
    private guessQCollGenerator() {
        opts.qcollg = guessBinary("qcollectiongenerator", QCOLLECTIONGENERATOR, opts.qcollg);
    }

    private guessBinary(string info, list candidates, *string optval) {
        list l = optval ? optval + candidates : candidates;
        ListIterator it(l);
        while (it.next()) {
            printf("%s: testing - %s\n", info, it.getValue());
            int rc;
            string ret = backquote(it.getValue() + " -h", \rc);
            if (!rc) {
                printf("    working, using this one\n");
                return it.getValue();
            }
            else {
                printf("    does not work. Trying next one\n");
            }
        }

        printf("\nNo proper %s found. Exiting.\n\n", info);
        exit(1);
    }

    private getProjectFiles(softlist srcdirs) {
        ListIterator it(srcdirs);
        list out = list();
        while (it.next()) {
            printf("Collecting index.qhp files in: %s\n", it.getValue());
            string cmd = sprintf("find \"%s\" -name index.qhp", it.getValue());
            printf("    shell: %s\n", cmd);
            string ret = backquote(cmd);
            out += ret.split("\n");
        }

        if (!out.size()) {
            printf("No index.qhp found in dirs: %y\n", srcdirs);
            exit(0);
        }

        return out;
    }
} # class Main

class QchFile {
    private {
        string m_fileName;
        bool m_valid = False;
    }

    constructor(string indexFile) {
        printf("QchFile: %N\n", indexFile);
        list l = indexFile.split("/");
        string basedir = dirname(indexFile);
        # path is ../../qore/qore/docs/lang/html/index.qhp and we want 'lang' as project
        string project = l[l.size()-3];
        m_fileName = sprintf("qore-%s-reference.qch", project);

        string cmd = sprintf("cd \"%s\";%s index.qhp -o \"%s/%s\"", basedir, opts.qhelpg, opts.outdir, m_fileName);
        printf("    shell: %s\n", cmd);
        int rc;
        string ret = backquote(cmd, \rc);
        if (rc) {
            printf("\nError processing %s\n%s\n\n", indexFile, ret);
            return;
        }

        m_valid = True;
    }

    bool isValid() {
        return m_valid;
    }

    string fileName() {
        return m_fileName;
    }

    private cp(string from, string to) {
        string cmd = sprintf("cp \"%s\" \"%s\"", from, to);
        printf(" shell: %s\n", cmd);
        backquote(cmd);
    }
} # class QchFile
 

class QHelpCollectionProject {

    private {
        hash temp = (
                "QHelpCollectionProject" : (
                    "^attributes^" : ( "version" : "1.0" ),
                    "assistant" : (
                        "title" : "Qore/Qorus Documentation",
                        "startPage" : "qthelp://org.qore.qore-lang/qore-lang/intro.html",
                        "currentFilter" : "qore-lang",
                        "applicationIcon" : "./logo.png",
                        "enableFilterFunctionality" : "true",
                        "enableDocumentationManager" : "true",
                        "enableAddressBar" : (
                             "^attributes^" : ( "visible" : "false"),
                             "^value^" : "true",
                        ),
#                        "cacheDirectory" : "mycompany/myapplication",
#                        "aboutMenuText" : (
#                            "text" : "Qore Langugage and Qorus Integration Server Documentation Bundle",
#                        ),
                        "aboutDialog" : (
                            "file" : "about.txt",
                            "icon" : "./logo.png",
                        ),
                    ),
                    "docFiles" : (
                        "register" : (
                            "file" : list(),
                        ),
                    ),
                ),
            );
    }

    constructor(softlist files) {
        ListIterator it(files);
        while (it.next()) {
            QchFile qch(it.getValue());
            if (!qch.isValid())
                continue;

            string fname = qch.fileName();
            if (fname == "qore-lang-reference.qch")
                 unshift temp.QHelpCollectionProject.docFiles.register.file, fname;
            else
                 push temp.QHelpCollectionProject.docFiles.register.file, fname;
        }

        string xml = make_xml(temp, XGF_ADD_FORMATTING);
#        printf("%N\n", xml);
        string qhcp = sprintf("%s/%s", opts.outdir, "qore-assistant-docs.qhcp");
        printf("final project file: %s\n", qhcp);

        File f();
        f.open2(qhcp, O_CREAT | O_TRUNC | O_WRONLY, 0644);
        f.write(xml);
        f.close();

        string cmd = sprintf("%s \"%s\" -o \"%s/qore-assistant-docs.qhc\"", opts.qcollg, qhcp, opts.outdir);
        printf("    shell: %s\n", cmd);
        int rc;
        string out = backquote(cmd, \rc);
#        printf("%s\n", out);
#        if (!rc) {
#            throw "QCOLLECTIONGENERATOR-EXE-ERROR";
#        }
    }


} # class QHelpCollectionProject



