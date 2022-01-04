# WebCTRL Certificate Manager

[This script](cert_manager.bat) helps to manage SSL certificates for *WebCTRL*. The script relies upon the *keytool* utility packaged with *WebCTRL*, so external software is not required. Since the script is a batch file, it can only be used on *Windows* operating systems. This script has been tested on *WebCTRL7.0* and *WebCTRL8.0*.

# Setup

1. Download the latest version of [*cert_manager.bat*](https://github.com/automatic-controls/webctrl-cert-manager/releases/latest/download/cert_manager.bat).

1. Place *cert_manager.bat* in *./webserver/keystores* relative to your *WebCTRL* installation folder.

1. Run *cert_manager.bat* and use the provided commands to manage your *WebCTRL* certificate.

   - It is suggested to shutdown the *WebCTRL* server before running the script.

# Commands

| Command | Description |
| - | - |
| `cls` | Clears the terminal. |
| `help` | Displays a help message listing these commands with brief descriptions. |
| `generate` | Generates a new 2048-bit RSA key-pair in the *./webserver/keystores/certkeys* keystore under the alias *webctrl*. |
| `request` | Creates a certificate signing request for your key-pair located at *./webserver/keystores/request.csr*. |
| `import [file]` | Imports the certificate reply chain. If your certificate reply contains multiple files, place all the files in a folder, and specify the absolute path of the folder as a parameter to this command. If no parameters are given, the script looks at all files in the *./webserver/keystores* directory. You may be required to manually download root or intermediate certificates from your CA. |
| `export` | Exports the public-key of your certificate to *./webserver/keystores/WebCTRL.cer* so that you may inspect the trust chain to ensure it is properly setup before restarting *WebCTRL*. |

All other commands are passed as parameters to *keytool*. Type `--help` for a list of valid *keytool* switches. Note the `-keystore` and `-storepass` switches are automatically populated by the script.

# Suggested Renewal Procedure

1. Shutdown the *WebCTRL* server.

1. Use the `generate` command to create a new key-pair.

1. Use the `request` command to create a new certificate signing request for your key-pair.

1. Submit *./webserver/keystores/request.csr* to your certificate authority (CA).

1. Download the certificate reply chain from your CA (including all necessary root and intermediate certificates). Place all the downloaded files into a folder.

1. Use the `import` command with the absolute path to the folder containing the downloaded files.

1. Use the `export` command, and inspect *./webserver/keystores/WebCTRL.cer* to ensure your certificate is trusted.

1. Restart the *WebCTRL* server.

# Additional Information

- *WebCTRL* stores the keystore password plain-text in *./webserver/conf/server.xml*. The script automatically retrieves the password from this file, which is why you won't be prompted for a password unless you are creating a new keystore.

- *WebCTRL* stores an obfuscation of the keystore password in *./resources/properties/settings.properties*. The obfuscation algorithm reverses the ordering and XOR's each character code with 4.

- To interface with *WebCTRL*, the script may edit *./webserver/conf/server.xml* and *./resources/properties/settings.properties* at various times. You shouldn't need to use *SiteBuilder* at any point in the process.

- Generated key-pairs are created with a validity of 10 years. Usually, certificate authorities provide their signature with a validity of 1 year, so key-pair validity should not be an issue. If your CA provides a validity greater than 10 years, you are welcome to edit the script (use **CTRL+F** to search for `-validity 3650`).

- Generated key-pairs are created with 2048-bit keys. If you would like a higher level of security (e.g, 4096-bit), you are welcome to edit the script (use **CTRL+F** to search for `-keysize 2048`).

- When filling out properties of generated key-pairs, certain characters may cause errors. You may attempt to escape special characters with a backslash.

- If *./webserver/keystores/certkeys* does not already exist, the script will create the keystore and edit *WebCTRL* configuration files to use the TLSv1.3 protocol with ciphers TLS_AES_256_GCM_SHA384,TLS_AES_128_GCM_SHA256 where *HTTP* connections are automatically redirected to *HTTPS*. If future versions of *WebCTRL* permit a more recent version of the TLS protocol, then the script should be updated.

- The keystore password must be at least 6 characters long. Due to batch file limitations, you may encounter errors if your keystore password contains any of the special characters *"&!%;?*