#!/usr/bin/env qore
%new-style

%requires xml


class QHelpCollectionProject {

    private {
        hash temp = (
                "QHelpCollectionProject" : (
                    "^attributes^" : ( "version" : "1.0" ),
                    "assistant" : (
                        "title" : "Qore/Qorus Documentation",
                        "startPage" : "qthelp://org.qore.qore-lang/qore-lang/intro.html",
                        "currentFilter" : "myfilter",
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
            printf("add: %s\n", it.getValue());
            # TODO/FIXME: check file existence, readability, etc.
            push temp.QHelpCollectionProject.docFiles.register.file, it.getValue();
        }

        string xml = makeFormattedXMLString(temp);
        printf("%N\n", xml);

        File f();
        f.open2("qore-assistant-docs.qhcp", O_CREAT | O_TRUNC | O_WRONLY, 0644);
        f.write(xml);
        f.close();

        int rc;
        string out = backquote("qcollectiongenerator-qt5 qore-assistant-docs.qhcp -o qore-assistant-docs.qhc", \rc);
        printf("%s\n", out);
#        if (!rc) {
#            throw "QCOLLECTIONGENERATOR-EXE-ERROR";
#        }
    }

} # class QHelpCollectionProject


new QHelpCollectionProject(ARGV);

