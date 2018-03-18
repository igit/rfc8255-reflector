# RFC8255 (Multiple Language Content Type) mail reflector
Aims of the reflector :
* receive text/plain mail with a source language
* translate text/plain from source language to chosen destination language(s) (one or more destination)
* build a multipart/multilingual (RFC8255) with original mail and translated parts
* reply to the original sender with the multipart/multilingual mail
![Reflector synoptic]({{site.baseurl}}/synoptic-rfc8255-reflector--draw.io)
