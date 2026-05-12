package pl.eengine.signaturetool.service;

public class InMemoryDocument {
    private final String uri;
    private final String mimeType;
    private final byte[] content;

    public InMemoryDocument(String uri, String mimeType, byte[] content) {
        this.uri = uri;
        this.mimeType = mimeType;
        this.content = content;
    }

    public String getUri() {
        return uri;
    }

    public String getMimeType() {
        return mimeType;
    }

    public byte[] getContent() {
        return content;
    }
}

