package pl.eengine.signaturetool.api.model;

import javax.validation.Valid;
import javax.validation.constraints.NotEmpty;
import java.util.List;

public class SignatureRequest {
    @Valid
    @NotEmpty
    private List<SignatureDocumentPayload> documents;

    public List<SignatureDocumentPayload> getDocuments() {
        return documents;
    }

    public void setDocuments(List<SignatureDocumentPayload> documents) {
        this.documents = documents;
    }
}
