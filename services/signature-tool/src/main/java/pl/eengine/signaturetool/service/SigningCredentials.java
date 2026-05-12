package pl.eengine.signaturetool.service;

import java.nio.file.Path;

public class SigningCredentials {
    private final Path certificatePath;
    private final String password;

    public SigningCredentials(Path certificatePath, String password) {
        this.certificatePath = certificatePath;
        this.password = password;
    }

    public Path getCertificatePath() {
        return certificatePath;
    }

    public String getPassword() {
        return password;
    }
}

