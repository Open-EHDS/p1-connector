package pl.eengine.signaturetool.api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import pl.eengine.signaturetool.api.model.SignatureRequest;
import pl.eengine.signaturetool.api.model.SignatureResponse;
import pl.eengine.signaturetool.service.XadesSignatureService;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(SignatureController.class)
class SignatureControllerTest {
    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private XadesSignatureService xadesSignatureService;

    @Test
    void returnsDetachedSignature() throws Exception {
        given(xadesSignatureService.generateDetachedSignature(any(SignatureRequest.class)))
                .willReturn(new SignatureResponse("<Signature/>", "PFNpZ25hdHVyZS8+"));

        mockMvc.perform(post("/api/v1/signatures/xades-detached")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"documents\":[{\"uri\":\"https://isus.ezdrowie.gov.pl/fhir/Patient/1/_history/2\",\"mimeType\":\"application/fhir+xml\",\"content\":\"<Patient xmlns=\\\"http://hl7.org/fhir\\\"/>\"}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.document").value("<Signature/>"))
                .andExpect(jsonPath("$.documentBase64").value("PFNpZ25hdHVyZS8+"));
    }

    @Test
    void validatesRequiredFields() throws Exception {
        mockMvc.perform(post("/api/v1/signatures/xades-detached")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"documents\":[]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("Bad Request"));
    }
}
