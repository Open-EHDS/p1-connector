package pl.eengine.signaturetool.service;

import org.springframework.stereotype.Component;
import pl.eengine.signaturetool.config.SigningCredentialsProperties;
import pl.eengine.signaturetool.web.SignatureGenerationException;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

@Component
public class SigningCredentialsProvider {
    private final SigningCredentialsProperties properties;

    public SigningCredentialsProvider(SigningCredentialsProperties properties) {
        this.properties = properties;
    }

    public SigningCredentials load() {
        String certificatePath = trimToNull(properties.getCertificatePath());
        if (certificatePath == null) {
            throw new SignatureGenerationException("Signing certificate path is not configured", null);
        }

        String password = resolvePassword();
        if (password == null) {
            throw new SignatureGenerationException("Signing certificate password is not configured", null);
        }

        Path path = Path.of(certificatePath);
        if (!Files.isReadable(path)) {
            throw new SignatureGenerationException("Signing certificate is not readable: " + certificatePath, null);
        }

        return new SigningCredentials(path, password);
    }

    private String resolvePassword() {
        String directPassword = trimToNull(properties.getPassword());
        if (directPassword != null) {
            return directPassword;
        }

        String passwordFile = trimToNull(properties.getPasswordFile());
        if (passwordFile == null) {
            return null;
        }

        try {
            return trimToNull(Files.readString(Path.of(passwordFile), StandardCharsets.UTF_8));
        } catch (IOException e) {
            throw new SignatureGenerationException("Could not read signing certificate password file: " + passwordFile, e);
        }
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}

