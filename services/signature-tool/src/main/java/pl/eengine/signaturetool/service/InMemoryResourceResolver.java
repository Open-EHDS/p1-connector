package pl.eengine.signaturetool.service;

import org.apache.xml.security.signature.XMLSignatureInput;
import org.apache.xml.security.utils.resolver.ResourceResolverContext;
import org.apache.xml.security.utils.resolver.ResourceResolverException;
import org.apache.xml.security.utils.resolver.ResourceResolverSpi;

import java.util.Map;

public class InMemoryResourceResolver extends ResourceResolverSpi {
    private final Map<String, InMemoryDocument> documents;

    public InMemoryResourceResolver(Map<String, InMemoryDocument> documents) {
        this.documents = documents;
    }

    @Override
    public XMLSignatureInput engineResolveURI(ResourceResolverContext context) throws ResourceResolverException {
        String resolvedUri = resolveUri(context.baseUri, context.uriToResolve);
        InMemoryDocument document = documents.get(resolvedUri);

        if (document == null) {
            throw new ResourceResolverException("signature_tool.missingDocument", new Object[]{resolvedUri}, resolvedUri, context.baseUri);
        }

        XMLSignatureInput result = new XMLSignatureInput(document.getContent());
        result.setMIMEType(document.getMimeType());
        result.setSourceURI(resolvedUri);
        result.setSecureValidation(context.secureValidation);

        return result;
    }

    @Override
    public boolean engineCanResolveURI(ResourceResolverContext context) {
        return documents.containsKey(resolveUri(context.baseUri, context.uriToResolve));
    }

    private String resolveUri(String baseUri, String uriToResolve) {
        String prefix = baseUri == null ? "" : baseUri;
        return prefix + uriToResolve;
    }
}

