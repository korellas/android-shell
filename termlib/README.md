# Terminal source patch

Kotlin sources and resources were imported from [org.connectbot:termlib:0.3.11](https://repo.maven.apache.org/maven2/org/connectbot/termlib/0.3.11/). Upstream copyright notices and the Apache license are preserved.

`ImeInputView` is patched locally for IME composition finalization. The native engine is extracted unchanged from the published AAR selected by `libs.termlib`; that coordinate must stay aligned with the imported source. The AAR's JVM classes are not packaged.
