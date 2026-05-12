package pl.eengine.signaturetool.service;

import org.apache.xml.security.utils.resolver.ResourceResolver;
import org.springframework.stereotype.Service;
import pl.eengine.signaturetool.api.model.SignatureDocumentPayload;
import pl.eengine.signaturetool.api.model.SignatureRequest;
import pl.eengine.signaturetool.api.model.SignatureResponse;
import pl.eengine.signaturetool.crypto.DirectPasswordProvider;
import pl.eengine.signaturetool.crypto.FirstCertificateSelector;
import pl.eengine.signaturetool.crypto.Sha256AlgorithmsProvider;
import pl.eengine.signaturetool.web.BadRequestException;
import pl.eengine.signaturetool.web.SignatureGenerationException;
import xades4j.production.DataObjectReference;
import xades4j.production.SignedDataObjects;
import xades4j.production.XadesBesSigningProfile;
import xades4j.production.XadesSigner;
import xades4j.properties.DataObjectDesc;
import xades4j.providers.KeyingDataProvider;
import xades4j.providers.impl.FileSystemKeyStoreKeyingDataProvider;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class XadesSignatureService {
    private final SigningCredentialsProvider signingCredentialsProvider;

    public XadesSignatureService(SigningCredentialsProvider signingCredentialsProvider) {
        this.signingCredentialsProvider = signingCredentialsProvider;
    }

    public SignatureResponse generateDetachedSignature(SignatureRequest request) {
        Map<String, InMemoryDocument> documents = normalizeDocuments(request.getDocuments());
        SigningCredentials credentials = signingCredentialsProvider.load();
        String signatureXml = sign(documents, credentials.getCertificatePath(), credentials.getPassword());
        return new SignatureResponse(signatureXml, Base64.getEncoder().encodeToString(signatureXml.getBytes(StandardCharsets.UTF_8)));
    }

    private Map<String, InMemoryDocument> normalizeDocuments(List<SignatureDocumentPayload> payloads) {
        Map<String, InMemoryDocument> documents = new LinkedHashMap<>();

        for (SignatureDocumentPayload payload : payloads) {
            byte[] content = decodeContent(payload);
            InMemoryDocument existing = documents.putIfAbsent(
                    payload.getUri(),
                    new InMemoryDocument(payload.getUri(), payload.getMimeType(), content)
            );

            if (existing != null) {
                throw new BadRequestException("Duplicate document URI: " + payload.getUri());
            }
        }

        return documents;
    }

    private byte[] decodeContent(SignatureDocumentPayload payload) {
        if (payload.getContent() == null || payload.getContent().isBlank()) {
            throw new BadRequestException("Document content must not be blank");
        }

        return payload.getContent().getBytes(StandardCharsets.UTF_8);
    }

    private String sign(Map<String, InMemoryDocument> documents, Path certificatePath, String password) {
        try {
            DocumentBuilderFactory documentBuilderFactory = DocumentBuilderFactory.newInstance();
            documentBuilderFactory.setNamespaceAware(true);

            org.w3c.dom.Document outputDocument = documentBuilderFactory.newDocumentBuilder().newDocument();
            DirectPasswordProvider passwordProvider = new DirectPasswordProvider(password);
            KeyingDataProvider keyingDataProvider = new FileSystemKeyStoreKeyingDataProvider(
                    "pkcs12",
                    certificatePath.toString(),
                    new FirstCertificateSelector(),
                    passwordProvider,
                    passwordProvider,
                    true
            );

            List<DataObjectDesc> references = documents.values().stream()
                    .map(document -> new DataObjectReference(document.getUri()))
                    .collect(Collectors.toList());

            SignedDataObjects signedDataObjects = new SignedDataObjects()
                    .withResourceResolver(new ResourceResolver(new InMemoryResourceResolver(documents)))
                    .withSignedDataObjects(references);

            XadesSigner signer = new XadesBesSigningProfile(keyingDataProvider)
                    .withAlgorithmsProviderEx(new Sha256AlgorithmsProvider())
                    .newSigner();

            signer.sign(signedDataObjects, outputDocument);

            TransformerFactory transformerFactory = TransformerFactory.newInstance();
            Transformer transformer = transformerFactory.newTransformer();
            transformer.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "no");
            transformer.setOutputProperty(OutputKeys.INDENT, "no");

            StringWriter writer = new StringWriter();
            transformer.transform(new DOMSource(outputDocument), new StreamResult(writer));
            return writer.toString();
        } catch (SignatureGenerationException e) {
            throw e;
        } catch (Exception e) {
            String detail = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
            throw new SignatureGenerationException("Could not generate detached XAdES signature: " + detail, e);
        }
    }
}
