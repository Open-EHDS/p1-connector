package pl.eengine.signaturetool.api.model;

public class SignatureResponse {
    private final String document;
    private final String documentBase64;

    public SignatureResponse(String document, String documentBase64) {
        this.document = document;
        this.documentBase64 = documentBase64;
    }

    public String getDocument() {
        return document;
    }

    public String getDocumentBase64() {
        return documentBase64;
    }
}

