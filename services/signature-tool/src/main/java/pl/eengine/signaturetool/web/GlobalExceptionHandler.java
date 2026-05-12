package pl.eengine.signaturetool.web;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import pl.eengine.signaturetool.api.model.ErrorResponse;

import javax.validation.ConstraintViolationException;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler({
            BadRequestException.class,
            ConstraintViolationException.class,
            MethodArgumentNotValidException.class
    })
    public ResponseEntity<ErrorResponse> handleBadRequest(Exception exception) {
        String message = exception instanceof MethodArgumentNotValidException
                ? ((MethodArgumentNotValidException) exception).getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + " " + error.getDefaultMessage())
                .collect(Collectors.joining(", "))
                : exception.getMessage();

        return buildResponse(HttpStatus.BAD_REQUEST, message);
    }

    @ExceptionHandler(SignatureGenerationException.class)
    public ResponseEntity<ErrorResponse> handleSignatureGeneration(SignatureGenerationException exception) {
        return buildResponse(HttpStatus.UNPROCESSABLE_ENTITY, exception.getMessage());
    }

    private ResponseEntity<ErrorResponse> buildResponse(HttpStatus status, String message) {
        return ResponseEntity.status(status)
                .body(new ErrorResponse(status.value(), status.getReasonPhrase(), message));
    }
}

