jng2-decrypt
====

Jets'n'Guns 2 stores most of its data files in `content.zip`. Extracting this is easy,
but most of the files in the zip are encrypted. This program decrypts these files for
you, making modding as simple as editing some ini files.

## How do I do?

* Download the program from [here](https://github.com/Hejsil/jng2-decrypt/releases/download/nightly/jng2-decrypt.exe)
* Find your Jets'n'Guns 2 game folder.
  * You can open it through steam by right clicking on jng2 and going:
    * Properties... -> Local Files -> Browse...
* Copy the program you downloaded to this folder.
* Run it.
  * Windows will probably complain that the program might be unsafe. All I can really
    say to this is that all the code is here and open. You can easily verify this is not
    a virus.
* Once the program completes there should be a `content` folder.
  * This folder contains all the decrypted data. `jng2-decrypt` tells Jets'n'Guns 2 to
    load the game data from this folder, so if you edit anything in it, it should change
    the games behavior.
* If you wonna play unedited Jets'n'Guns 2, you can edit the `content.txt` file to be
  this:
  ```
  // dir = content
  zip = content.zip
  ```
