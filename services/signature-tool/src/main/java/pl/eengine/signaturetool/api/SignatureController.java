package pl.eengine.signaturetool.api;

import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import pl.eengine.signaturetool.api.model.SignatureRequest;
import pl.eengine.signaturetool.api.model.SignatureResponse;
import pl.eengine.signaturetool.service.XadesSignatureService;

import javax.validation.Valid;

@RestController
@Validated
@RequestMapping("/api/v1/signatures")
public class SignatureController {
    private final XadesSignatureService xadesSignatureService;

    public SignatureController(XadesSignatureService xadesSignatureService) {
        this.xadesSignatureService = xadesSignatureService;
    }

    @PostMapping("/xades-detached")
    @ResponseStatus(HttpStatus.OK)
    public SignatureResponse generateDetachedSignature(@Valid @RequestBody SignatureRequest request) {
        return xadesSignatureService.generateDetachedSignature(request);
    }
}

