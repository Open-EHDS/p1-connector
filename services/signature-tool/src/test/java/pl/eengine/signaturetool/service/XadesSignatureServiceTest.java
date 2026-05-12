package pl.eengine.signaturetool.service;

import org.junit.jupiter.api.Test;
import pl.eengine.signaturetool.api.model.SignatureDocumentPayload;
import pl.eengine.signaturetool.api.model.SignatureRequest;
import pl.eengine.signaturetool.api.model.SignatureResponse;
import pl.eengine.signaturetool.config.SigningCredentialsProperties;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.net.URISyntaxException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class XadesSignatureServiceTest {
    @Test
    void generatesDetachedXadesFromConfiguredCertificate() throws Exception {
        SigningCredentialsProperties properties = new SigningCredentialsProperties();
        properties.setCertificatePath(testCertificatePath().toString());
        properties.setPassword("1234567890");

        XadesSignatureService service = new XadesSignatureService(new SigningCredentialsProvider(properties));

        SignatureDocumentPayload patient = new SignatureDocumentPayload();
        patient.setUri("https://isus.ezdrowie.gov.pl/fhir/Patient/pat-123/_history/7");
        patient.setMimeType("application/fhir+xml");
        patient.setContent("<Patient xmlns=\"http://hl7.org/fhir\"><id value=\"pat-123\"/></Patient>");

        SignatureDocumentPayload encounter = new SignatureDocumentPayload();
        encounter.setUri("https://isus.ezdrowie.gov.pl/fhir/Encounter/enc-123/_history/1");
        encounter.setMimeType("application/fhir+xml");
        encounter.setContent("<Encounter xmlns=\"http://hl7.org/fhir\"><id value=\"enc-123\"/></Encounter>");

        SignatureRequest request = new SignatureRequest();
        request.setDocuments(List.of(patient, encounter));

        SignatureResponse response = service.generateDetachedSignature(request);

        assertNotNull(response.getDocument());
        assertNotNull(response.getDocumentBase64());
        assertTrue(response.getDocument().contains("<ds:Signature"));
        assertTrue(response.getDocument().contains(patient.getUri()));
        assertTrue(response.getDocument().contains(encounter.getUri()));
        assertEquals(
                response.getDocument(),
                new String(java.util.Base64.getDecoder().decode(response.getDocumentBase64()), java.nio.charset.StandardCharsets.UTF_8)
        );
    }

    private Path testCertificatePath() throws URISyntaxException {
        return Paths.get(getClass().getResource("/fixtures/CezarySzybki.pfx").toURI());
    }
}
