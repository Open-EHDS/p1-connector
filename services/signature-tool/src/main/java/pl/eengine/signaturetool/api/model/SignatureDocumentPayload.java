package pl.eengine.signaturetool.api.model;

import javax.validation.constraints.NotBlank;

public class SignatureDocumentPayload {
    @NotBlank
    private String uri;

    @NotBlank
    private String mimeType;

    @NotBlank
    private String content;

    public String getUri() {
        return uri;
    }

    public void setUri(String uri) {
        this.uri = uri;
    }

    public String getMimeType() {
        return mimeType;
    }

    public void setMimeType(String mimeType) {
        this.mimeType = mimeType;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }
}
