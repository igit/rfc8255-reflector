# RFC8255 (Multiple Language Content Type) mail reflector

**Quick links :**
* [How to install](#how-to-install)
* [How to use](#how-to-use)
* [Online reflector](#online-reflector)

**Aims of the reflector :**
* receive text/plain mail with a source language
* translate text/plain from source language to chosen destination language(s) (one or more destination)
* build a multipart/multilingual ([RFC8255](https://trac.tools.ietf.org/html/rfc8255)) with original mail and translated parts
* reply to the original sender with the multipart/multilingual mail

![Reflector synoptic](synoptic-rfc8255-reflector--draw.io.png)

# How to install
One can use the rfc8255-reflector.pl on a Unix server with MTA able to pipe incoming message to a script.

Here is an example of installation on a Linux (Debian) server with Postfix :

```
$ useradd -m -s /bin/false reflector
$ cd /home/reflector
$ mkdir bin
$ curl https://raw.githubusercontent.com/igit/rfc8255-reflector/master/rfc8255-reflector.pl -o bin/rfc8255-reflector.pl
$ chmod 755 bin/rfc8255-reflector.pl
$ perl -c bin/rfc8255-reflector.pl
  rfc8255-reflector.pl syntax OK
  ## else fix perl modules that are missing
$ echo "|/home/reflector/bin/rfc8255-reflector.pl" > .forward
$ chown -R reflector:`id -g reflector` .forward bin
```

# How to use
Simply send a mail to the "reflector" user by specifing the source language and the destination language(s) requested for translation and for building a [RFC8255](https://trac.tools.ietf.org/html/rfc8255) mail :

```
$ echo "Hello world !" > body.txt
$ mutt -s "First test" reflector+sl_en+tl_fr+tl_es+tl_de@example.com < body.txt
```

The field To: is used to drive the reflector like this :
* **+sl_** *en* : **sl_** = source language ; *en* = english
* **+tl_** *fr* : **tl_** = target language ; *fr* = french
* **+tl_** *es* : **tl_** = target language ; *es* = spanish
* **+tl_** *de* : **tl_** = target language ; *de* = german

Then, the reflector build a [RFC8255](https://trac.tools.ietf.org/html/rfc8255) mail and reply to you.

# Online reflector
An instance of the reflector is available for testing at this e-mail address : 

```
reflector[… +options …] AT rfc8255 DOT as-home DOT fr
```
Be aware that :
* the service is proposed *as it is*, no guarantee, best efforts
* the e-mail server hosting the service implements stricts anti-spam rules, you must send your e-mail from client/server well configured
* if abuses are detected, the service will be disabled ... and maybe remove

*Thank you for respecting that !*
*-- the hoster*
